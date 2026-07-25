from datetime import datetime, timezone
from typing import Any

import socketio
from socketio.exceptions import ConnectionRefusedError

from app.core.exceptions import TashilaException
from app.core.redis import publish
from app.services import driver_service, trip_service

ADMIN_MAP_ROOM = "admin:map"
LOCATION_TRIP_STATUSES = frozenset(
    {"accepted", "headingToPickup", "inProgress"},
)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


async def _get_session(server: socketio.AsyncServer, sid: str) -> dict[str, Any]:
    try:
        return await server.get_session(sid)
    except KeyError as exc:
        raise ConnectionRefusedError("Session not found") from exc


def _require_driver(session: dict[str, Any]) -> str:
    if session.get("role") != "driver":
        raise ConnectionRefusedError("Driver access only")
    user_id = session.get("userId")
    if not user_id:
        raise ConnectionRefusedError("Invalid session")
    return user_id


def _optional_float(value: Any) -> float | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    raise ValueError("Expected number or null")


def _validate_location_payload(data: dict[str, Any] | None) -> tuple[float, float, float | None, float | None]:
    if not data:
        raise ValueError("Location data is required")
    if "lat" not in data or "lng" not in data:
        raise ValueError("lat and lng are required")
    lat = data["lat"]
    lng = data["lng"]
    if not isinstance(lat, (int, float)) or not isinstance(lng, (int, float)):
        raise ValueError("lat and lng must be numbers")
    heading = _optional_float(data.get("heading"))
    speed = _optional_float(data.get("speed"))
    return float(lat), float(lng), heading, speed


async def _emit_tashila_error(server: socketio.AsyncServer, sid: str, exc: TashilaException) -> None:
    from app.core.exceptions import ConflictError

    payload: dict[str, Any] = {"message": exc.message}
    if isinstance(exc, ConflictError) and exc.code:
        payload["code"] = exc.code
    await server.emit("trip:error", payload, to=sid)


def register_driver_handlers(server: socketio.AsyncServer) -> None:
    from app.socket.client_handlers import notify_driver_assigned, notify_trip_status_changed
    from app.socket.manager import emit_to_trip_room

    @server.on("driver:online")
    async def on_driver_online(sid: str, data: dict[str, Any] | None = None) -> None:
        session = await _get_session(server, sid)
        driver_id = _require_driver(session)
        try:
            await driver_service.set_availability(driver_id, "online")
            driver = await driver_service.get_driver_doc(driver_id)
        except TashilaException as exc:
            await _emit_tashila_error(server, sid, exc)
            return

        await server.emit(
            "admin:driver_went_online",
            {
                "driverId": driver_id,
                "name": driver.get("name"),
                "truckType": driver.get("truckType"),
            },
            room=ADMIN_MAP_ROOM,
        )

    @server.on("driver:offline")
    async def on_driver_offline(sid: str, data: dict[str, Any] | None = None) -> None:
        session = await _get_session(server, sid)
        driver_id = _require_driver(session)
        try:
            await driver_service.set_availability(driver_id, "offline")
        except TashilaException as exc:
            await _emit_tashila_error(server, sid, exc)
            return

        await server.emit(
            "admin:driver_went_offline",
            {"driverId": driver_id},
            room=ADMIN_MAP_ROOM,
        )

    @server.on("driver:location_update")
    async def on_location_update(sid: str, data: dict[str, Any]) -> None:
        session = await _get_session(server, sid)
        driver_id = _require_driver(session)
        try:
            lat, lng, heading, speed = _validate_location_payload(data)
            await driver_service.update_driver_location(driver_id, lat, lng)
        except (ValueError, TashilaException) as exc:
            message = exc.message if isinstance(exc, TashilaException) else str(exc)
            await server.emit("trip:error", {"message": message}, to=sid)
            return

        active_trip = await trip_service.get_active_trip_for_driver(driver_id)
        if active_trip and active_trip.get("status") in LOCATION_TRIP_STATUSES:
            trip_id = active_trip["id"]
            await emit_to_trip_room(
                trip_id,
                "trip:driver_location",
                {
                    "tripId": trip_id,
                    "lat": lat,
                    "lng": lng,
                    "heading": heading,
                },
            )

        await publish(
            "driver:location",
            {
                "driverId": driver_id,
                "lat": lat,
                "lng": lng,
                "heading": heading,
                "speed": speed,
            },
        )

    @server.on("driver:trip_request_response")
    async def on_trip_response(sid: str, data: dict[str, Any]) -> None:
        session = await _get_session(server, sid)
        driver_id = _require_driver(session)
        if not data or not data.get("tripId"):
            await server.emit("trip:error", {"message": "tripId is required"}, to=sid)
            return

        trip_id = str(data["tripId"])
        accepted = bool(data.get("accepted"))

        if accepted:
            try:
                await trip_service.accept_trip(trip_id, driver_id)
                # notify_driver_assigned is fired by redis_bridge on trip:accepted
                await server.enter_room(sid, f"trip:{trip_id}")
            except TashilaException as exc:
                await _emit_tashila_error(server, sid, exc)
        else:
            await trip_service.reject_trip(trip_id, driver_id)

    @server.on("trip:status_update")
    async def on_status_update(sid: str, data: dict[str, Any]) -> None:
        session = await _get_session(server, sid)
        driver_id = _require_driver(session)
        if not data or not data.get("tripId") or not data.get("status"):
            await server.emit("trip:error", {"message": "tripId and status are required"}, to=sid)
            return

        trip_id = str(data["tripId"])
        new_status = str(data["status"])
        try:
            updated = await trip_service.advance_trip_status(trip_id, driver_id, new_status)
        except TashilaException as exc:
            await _emit_tashila_error(server, sid, exc)
            return

        await notify_trip_status_changed(trip_id, new_status)
        await server.emit(
            "admin:trip_status_changed",
            {
                "tripId": trip_id,
                "status": new_status,
                "driverId": driver_id,
                "updatedAt": now_iso(),
            },
            room=ADMIN_MAP_ROOM,
        )
