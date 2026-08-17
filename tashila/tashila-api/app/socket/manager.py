from datetime import datetime, timezone
from typing import Any

from bson import ObjectId
from bson.errors import InvalidId
from fastapi import HTTPException
from socketio.exceptions import ConnectionRefusedError

from app.core.database import get_database
from app.core.redis import (
    get_driver_socket,
    is_token_blacklisted,
    remove_driver_socket,
    set_driver_socket,
)
from app.core.security import decode_any_token
from app.socket import sio

DRIVERS_COLLECTION = "drivers"
ADMIN_MAP_ROOM = "admin:map"


def _extract_token(auth: dict[str, Any] | None) -> str:
    if not auth:
        return ""
    token = str(auth.get("token", "") or "").strip()
    if token.lower().startswith("bearer "):
        token = token.removeprefix("Bearer ").removeprefix("bearer ")
    return token.strip()


@sio.event
async def connect(sid: str, environ: dict, auth: dict[str, Any] | None = None) -> None:
    token = _extract_token(auth)
    if not token:
        raise ConnectionRefusedError("Unauthorized")

    try:
        payload = decode_any_token(token)
    except HTTPException as exc:
        raise ConnectionRefusedError(exc.detail if isinstance(exc.detail, str) else "Unauthorized")

    jti = payload.get("jti")
    if jti and await is_token_blacklisted(jti):
        raise ConnectionRefusedError("Token revoked")

    user_id = payload["sub"]
    role = payload["role"]
    await sio.save_session(sid, {"userId": user_id, "role": role})

    if role == "driver":
        await set_driver_socket(user_id, sid)
        await sio.enter_room(sid, f"driver:{user_id}")
    elif role == "admin":
        await sio.enter_room(sid, ADMIN_MAP_ROOM)

    print(f"[Socket] {role} {user_id} connected as {sid}")


@sio.event
async def disconnect(sid: str) -> None:
    try:
        session = await sio.get_session(sid)
    except KeyError:
        print(f"[Socket] {sid} disconnected")
        return

    user_id = session.get("userId")
    role = session.get("role")

    if role == "driver" and user_id:
        await remove_driver_socket(user_id)
        try:
            driver_oid = ObjectId(user_id)
        except (InvalidId, TypeError):
            driver_oid = None

        if driver_oid is not None:
            from app.services.trip_service import get_active_trip_for_driver

            active_trip = await get_active_trip_for_driver(user_id)
            if active_trip is None:
                driver = await get_database()[DRIVERS_COLLECTION].find_one({"_id": driver_oid})
                if driver and driver.get("availability") == "online":
                    now = datetime.now(timezone.utc)
                    await get_database()[DRIVERS_COLLECTION].update_one(
                        {"_id": driver_oid},
                        {"$set": {"availability": "offline", "updatedAt": now}},
                    )
        await sio.emit(
            "admin:driver_went_offline",
            {"driverId": user_id},
            room=ADMIN_MAP_ROOM,
        )

    print(f"[Socket] {sid} disconnected")


async def emit_to_driver(driver_id: str, event: str, data: dict[str, Any]) -> None:
    await sio.emit(event, data, room=f"driver:{driver_id}")


async def emit_to_trip_room(trip_id: str, event: str, data: dict[str, Any]) -> None:
    await sio.emit(event, data, room=f"trip:{trip_id}")
