from datetime import datetime, timezone
from typing import Any

import socketio
from socketio.exceptions import ConnectionRefusedError

from app.core.exceptions import TashilaException
from app.services import trip_service


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _trip_id_from_data(data: dict[str, Any] | None) -> str:
    if not data or not data.get("tripId"):
        raise ValueError("tripId is required")
    return str(data["tripId"])


async def _get_session(server: socketio.AsyncServer, sid: str) -> dict[str, Any]:
    try:
        return await server.get_session(sid)
    except KeyError as exc:
        raise ConnectionRefusedError("Session not found") from exc


def _driver_notify_payload(driver: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": driver.get("id") or driver.get("_id"),
        "name": driver.get("name"),
        "phone": driver.get("phone"),
        "truckType": driver.get("truckType"),
        "rating": driver.get("rating"),
        "vehiclePlate": driver.get("vehiclePlate"),
        "vehicleColor": driver.get("vehicleColor"),
        "vehicleModel": driver.get("vehicleModel"),
    }


def register_client_handlers(server: socketio.AsyncServer) -> None:
    from app.socket.manager import emit_to_trip_room

    @server.on("trip:join")
    async def on_trip_join(sid: str, data: dict[str, Any]) -> None:
        session = await _get_session(server, sid)
        role = session.get("role")
        if role not in ("client", "admin", "driver"):
            raise ConnectionRefusedError("Only clients, drivers, and admins may join trip rooms")

        trip_id = _trip_id_from_data(data)
        trip = await trip_service.get_trip_by_id(trip_id)
        if role == "client" and trip.get("clientId") != session["userId"]:
            raise ConnectionRefusedError("Forbidden")
        if role == "driver" and trip.get("driverId") != session["userId"]:
            raise ConnectionRefusedError("Forbidden")

        await server.enter_room(sid, f"trip:{trip_id}")
        await server.emit(
            "trip:joined",
            {"tripId": trip_id, "currentStatus": trip.get("status")},
            to=sid,
        )

    @server.on("trip:leave")
    async def on_trip_leave(sid: str, data: dict[str, Any]) -> None:
        trip_id = _trip_id_from_data(data)
        await server.leave_room(sid, f"trip:{trip_id}")

    @server.on("trip:cancel")
    async def on_trip_cancel(sid: str, data: dict[str, Any]) -> None:
        session = await _get_session(server, sid)
        if session.get("role") != "client":
            raise ConnectionRefusedError("Only clients may cancel trips via socket")

        trip_id = _trip_id_from_data(data)
        try:
            await trip_service.cancel_trip(
                trip_id,
                session["userId"],
                data.get("reason"),
            )
        except TashilaException as exc:
            await server.emit("trip:error", {"message": exc.message}, to=sid)
            return

        await emit_to_trip_room(
            trip_id,
            "trip:status_changed",
            {"tripId": trip_id, "status": "cancelled", "updatedAt": now_iso()},
        )


async def notify_trip_status_changed(
    trip_id: str,
    status: str,
    extra: dict[str, Any] | None = None,
) -> None:
    from app.socket.manager import emit_to_trip_room

    payload: dict[str, Any] = {
        "tripId": trip_id,
        "status": status,
        "updatedAt": now_iso(),
    }
    if extra:
        payload.update(extra)

    # Include server-authoritative timestamps so clients can display real trip duration.
    if status in ("inProgress", "awaitingCash", "completed"):
        try:
            trip = await trip_service.get_trip_by_id(trip_id)
            if status == "inProgress" and trip.get("startedAt"):
                started = trip["startedAt"]
                payload["startedAt"] = (
                    started.isoformat() if hasattr(started, "isoformat") else str(started)
                )
            if status in ("awaitingCash", "completed") and trip.get("completedAt"):
                completed = trip["completedAt"]
                payload["completedAt"] = (
                    completed.isoformat() if hasattr(completed, "isoformat") else str(completed)
                )
            if status in ("awaitingCash", "completed") and trip.get("startedAt"):
                started = trip["startedAt"]
                payload.setdefault(
                    "startedAt",
                    started.isoformat() if hasattr(started, "isoformat") else str(started),
                )
        except Exception:
            pass  # Non-critical — client falls back to local timestamps

    await emit_to_trip_room(trip_id, "trip:status_changed", payload)


async def notify_driver_assigned(trip_id: str, driver: dict[str, Any]) -> None:
    from app.socket.manager import emit_to_trip_room

    await emit_to_trip_room(
        trip_id,
        "trip:driver_assigned",
        {
            "tripId": trip_id,
            "driver": _driver_notify_payload(driver),
        },
    )


async def notify_no_drivers_found(trip_id: str) -> None:
    from app.socket.manager import emit_to_trip_room

    trip = await trip_service.cancel_trip_no_driver(trip_id)
    if trip.get("status") != "cancelled":
        return

    payload = {
        "tripId": trip_id,
        "status": "cancelled",
        "cancelledReason": "no_drivers_found",
        "reason": "no_drivers_found",
        "message": "No drivers available nearby",
        "updatedAt": now_iso(),
    }
    await emit_to_trip_room(trip_id, "trip:no_drivers_found", payload)
    await emit_to_trip_room(trip_id, "trip:status_changed", payload)


async def notify_fare_updated(trip_id: str, final_fare: float) -> None:
    from app.socket.manager import emit_to_trip_room

    await emit_to_trip_room(
        trip_id,
        "trip:fare_updated",
        {"tripId": trip_id, "finalFare": final_fare},
    )
