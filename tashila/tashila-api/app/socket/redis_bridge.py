import asyncio
import json
import logging
from typing import Any

from app.core.redis import get_pubsub
from app.services import driver_service, trip_service
from app.services import dispatch_service
from app.socket import sio
from app.socket.client_handlers import notify_driver_assigned, notify_no_drivers_found, notify_trip_status_changed
from app.socket.manager import ADMIN_MAP_ROOM, emit_to_driver

logger = logging.getLogger(__name__)

SUBSCRIBED_CHANNELS = (
    "trip:accepted",
    "trip:status_changed",
    "trip:cancelled_by_client",
    "trip:rejected_by_driver",
    "dispatch:wake",
    "driver:location",
    "driver:availability_changed",
    "driver:doc_submitted",
)


async def handle_channel(channel: str, data: dict[str, Any]) -> None:
    try:
        if channel == "dispatch:wake":
            trip_id = data.get("tripId")
            if trip_id:
                dispatch_service.notify_dispatch_wake(str(trip_id))

        elif channel == "trip:accepted":
            trip_id = data.get("tripId")
            driver_id = data.get("driverId")
            if trip_id and driver_id:
                driver = await driver_service.get_driver_doc(driver_id)
                await notify_driver_assigned(trip_id, driver)
                await sio.emit(
                    "admin:trip_status_changed",
                    {
                        "tripId": trip_id,
                        "status": "accepted",
                        "driverId": driver_id,
                    },
                    room=ADMIN_MAP_ROOM,
                )

        elif channel == "trip:status_changed":
            trip_id = data.get("tripId")
            status = data.get("status")
            if trip_id and status:
                await notify_trip_status_changed(trip_id, status, extra=data)
                await sio.emit(
                    "admin:trip_status_changed",
                    {
                        "tripId": trip_id,
                        "status": status,
                        "driverId": data.get("driverId"),
                    },
                    room=ADMIN_MAP_ROOM,
                )
                if status in ("cancelled", "completed") and data.get("driverId"):
                    await dispatch_service.on_trip_finished(data["driverId"])

        elif channel == "trip:cancelled_by_client":
            driver_id = data.get("driverId")
            trip_id = data.get("tripId")
            if driver_id and trip_id:
                await emit_to_driver(
                    driver_id,
                    "driver:trip_cancelled",
                    {
                        "tripId": trip_id,
                        "reason": data.get("reason"),
                        "status": "cancelled",
                    },
                )
                trip = await trip_service.get_trip_by_id(trip_id)
                if trip.get("driverId") == driver_id and trip.get("status") in (
                    "accepted",
                    "headingToPickup",
                    "inProgress",
                ):
                    await dispatch_service.on_trip_finished(driver_id)

        elif channel == "trip:rejected_by_driver":
            trip_id = data.get("tripId")
            driver_id = data.get("driverId")
            if trip_id and driver_id:
                await dispatch_service.advance_after_reject(trip_id, driver_id)

        elif channel == "driver:location":
            await sio.emit(
                "admin:driver_location",
                {
                    "driverId": data.get("driverId"),
                    "lat": data.get("lat"),
                    "lng": data.get("lng"),
                    "heading": data.get("heading"),
                    "speed": data.get("speed"),
                },
                room=ADMIN_MAP_ROOM,
            )

        elif channel == "driver:doc_submitted":
            await sio.emit(
                "admin:approval_pending",
                {
                    "driverId": data.get("driverId"),
                    "documentType": data.get("documentType"),
                },
                room=ADMIN_MAP_ROOM,
            )

    except Exception:
        logger.exception("Redis bridge handler failed for channel=%s", channel)


async def start_redis_bridge() -> None:
    pubsub = get_pubsub()
    await pubsub.subscribe(*SUBSCRIBED_CHANNELS)
    logger.info("Redis bridge listening on channels: %s", ", ".join(SUBSCRIBED_CHANNELS))

    try:
        async for message in pubsub.listen():
            if message["type"] != "message":
                continue

            channel = message["channel"]
            if isinstance(channel, bytes):
                channel = channel.decode()

            raw = message["data"]
            if isinstance(raw, bytes):
                raw = raw.decode()

            data = json.loads(raw)
            asyncio.create_task(handle_channel(channel, data))

    except asyncio.CancelledError:
        logger.info("Redis bridge shutting down")
        await pubsub.unsubscribe()
        await pubsub.aclose()
        raise
