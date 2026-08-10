"""Uber-style sequential exclusive trip dispatch with Redis-backed offers."""
from __future__ import annotations

import asyncio
import logging
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any

from bson import ObjectId

from app.core.config import settings
from app.core.database import get_database
from app.core.exceptions import ConflictError
from app.core.redis import (
    acquire_dispatch_lock,
    clear_driver_busy,
    clear_trip_offer,
    get_driver_offer_trip_id,
    get_driver_socket,
    get_trip_offer,
    is_driver_busy,
    is_trip_rejected_by_driver,
    publish,
    push_dispatch_wake,
    release_dispatch_lock,
    set_driver_busy,
    set_trip_offer,
)
from app.services import trip_service
from app.services.notification_service import push_trip_request
from app.socket.client_handlers import notify_no_drivers_found
from app.socket.manager import emit_to_driver
from app.utils.geo import estimate_minutes, haversine_km

logger = logging.getLogger(__name__)

DRIVERS_COLLECTION = "drivers"
TRIPS_COLLECTION = "trips"
GEO_MAX_DISTANCE_METERS = 50_000

_dispatch_tasks: dict[str, asyncio.Task[None]] = {}
_dispatch_wake: dict[str, asyncio.Event] = {}


def _trip_id_from_payload(trip: dict[str, Any]) -> str:
    return str(trip.get("id") or trip.get("_id") or trip.get("tripId", ""))


def _pickup_near_point(trip: dict[str, Any]) -> dict[str, Any]:
    pickup = trip.get("pickup") or {}
    return {
        "type": "Point",
        "coordinates": [float(pickup["lng"]), float(pickup["lat"])],
    }


def _trip_route_payload(trip: dict[str, Any]) -> tuple[float, int]:
    pickup = trip.get("pickup") or {}
    dropoff = trip.get("dropoff") or {}
    stored_km = trip.get("distanceKm")
    stored_min = trip.get("estimatedMinutes")
    if stored_km is not None and float(stored_km) > 0:
        distance_km = round(float(stored_km), 1)
    elif pickup and dropoff:
        distance_km = round(
            haversine_km(
                float(pickup["lat"]),
                float(pickup["lng"]),
                float(dropoff["lat"]),
                float(dropoff["lng"]),
            ),
            1,
        )
    else:
        distance_km = 0.0
    if stored_min is not None and int(stored_min) > 0:
        minutes = int(stored_min)
    else:
        minutes = estimate_minutes(distance_km)
    return distance_km, minutes


async def _driver_ids_with_active_trips() -> set[str]:
    active_statuses = list(trip_service.DRIVER_ACTIVE_TRIP_STATUSES)
    ids: set[str] = set()
    async for doc in get_database()[TRIPS_COLLECTION].find(
        {"driverId": {"$ne": None}, "status": {"$in": active_statuses}},
        projection={"driverId": 1},
    ):
        if doc.get("driverId"):
            ids.add(str(doc["driverId"]))
    return ids


async def find_dispatch_candidates(trip: dict[str, Any]) -> list[dict[str, Any]]:
    truck_type = trip.get("truckType")
    near = _pickup_near_point(trip)
    busy_mongo = await _driver_ids_with_active_trips()
    pipeline: list[dict[str, Any]] = [
        {
            "$geoNear": {
                "near": near,
                "distanceField": "distanceMeters",
                "maxDistance": GEO_MAX_DISTANCE_METERS,
                "spherical": True,
                "key": "location",
                "query": {
                    "availability": "online",
                    "approvalStatus": "approved",
                    "truckType": truck_type,
                    "location": {"$exists": True},
                },
            },
        },
        {"$limit": settings.max_dispatch_candidates * 3},
    ]
    candidates: list[dict[str, Any]] = []
    async for doc in get_database()[DRIVERS_COLLECTION].aggregate(pipeline):
        driver_id = str(doc["_id"])
        if driver_id in busy_mongo:
            continue
        if await is_driver_busy(driver_id):
            continue
        candidates.append({**doc, "id": driver_id})
        if len(candidates) >= settings.max_dispatch_candidates:
            break
    return candidates


def _offer_socket_payload(
    trip: dict[str, Any],
    driver: dict[str, Any],
    *,
    expires_at: datetime,
    generation: int,
) -> dict[str, Any]:
    trip_id = _trip_id_from_payload(trip)
    client = trip.get("client") or {}
    route_km, route_minutes = _trip_route_payload(trip)
    pickup_distance_km = round(driver.get("distanceMeters", 0) / 1000, 1)
    offered_at = expires_at - timedelta(seconds=settings.offer_ttl_seconds)
    return {
        "tripId": trip_id,
        "pickup": trip.get("pickup"),
        "dropoff": trip.get("dropoff"),
        "fare": trip.get("fare"),
        "distanceKm": route_km,
        "estimatedDurationMinutes": route_minutes,
        "pickupDistanceKm": pickup_distance_km,
        "offeredAt": offered_at.isoformat(),
        "expiresAt": expires_at.isoformat(),
        "offerGeneration": generation,
        "client": {
            "name": client.get("name"),
            "phone": client.get("phone"),
            "avatarUrl": client.get("avatarUrl"),
            "rating": client.get("rating", 5.0),
        },
    }


async def offer_to_driver(
    trip: dict[str, Any],
    driver: dict[str, Any],
    *,
    candidate_index: int,
    generation: int,
) -> datetime:
    trip_id = _trip_id_from_payload(trip)
    driver_id = driver["id"]
    ttl = settings.offer_ttl_seconds
    offered_at = datetime.now(timezone.utc).replace(microsecond=0)
    expires_at = offered_at + timedelta(seconds=ttl)

    await set_trip_offer(
        trip_id,
        driver_id=driver_id,
        expires_at=expires_at.isoformat(),
        generation=generation,
        candidate_index=candidate_index,
        ttl_seconds=ttl + 120,
    )

    payload = _offer_socket_payload(trip, driver, expires_at=expires_at, generation=generation)
    if await get_driver_socket(driver_id):
        await emit_to_driver(driver_id, "driver:trip_request", payload)
    else:
        logger.info(
            "offer_to_driver: driver %s has no socket; HTTP current-offer fallback",
            driver_id,
        )

    pickup = trip.get("pickup") or {}
    pickup_address = pickup.get("address") or "Pickup location"
    await push_trip_request(driver_id, pickup_address, float(trip.get("fare") or 0))
    return expires_at


async def emit_offer_expired(trip_id: str, driver_id: str, *, reason: str) -> None:
    offer = await get_trip_offer(trip_id)
    expires_at = (offer or {}).get("expiresAt")
    await emit_to_driver(
        driver_id,
        "driver:offer_expired",
        {
            "tripId": trip_id,
            "reason": reason,
            "expiresAt": expires_at,
        },
    )


async def advance_offer(trip_id: str, reason: str) -> None:
    offer = await get_trip_offer(trip_id)
    if offer:
        driver_id = offer.get("driverId")
        if driver_id:
            await emit_offer_expired(trip_id, driver_id, reason=reason)
        await clear_trip_offer(trip_id)
    await signal_dispatch_wake(trip_id)


async def signal_dispatch_wake(trip_id: str) -> None:
    """Notify dispatch workers (local + other processes) to advance offer window."""
    wake = _dispatch_wake.get(trip_id)
    if wake:
        wake.set()
    try:
        await push_dispatch_wake(trip_id)
        await publish("dispatch:wake", {"tripId": trip_id})
    except Exception:
        logger.exception("signal_dispatch_wake failed for trip %s", trip_id)


def notify_dispatch_wake(trip_id: str) -> None:
    """Called from Redis bridge when another process signals wake."""
    wake = _dispatch_wake.get(trip_id)
    if wake:
        wake.set()


async def validate_reject(trip_id: str, driver_id: str) -> None:
    trip = await trip_service.get_trip_by_id(trip_id)
    if trip.get("status") != "requested":
        raise ConflictError("Trip is no longer available", code="TRIP_NOT_AVAILABLE")

    offer = await get_trip_offer(trip_id)
    if offer is None:
        raise ConflictError("No active offer for this trip", code="NOT_YOUR_OFFER")
    if offer.get("driverId") != driver_id:
        raise ConflictError("This trip was offered to another driver", code="NOT_YOUR_OFFER")


async def validate_accept(trip_id: str, driver_id: str) -> None:
    trip = await trip_service.get_trip_by_id(trip_id)
    if trip.get("status") != "requested":
        raise ConflictError("Trip already taken", code="TRIP_NOT_AVAILABLE")

    if await is_driver_busy(driver_id):
        raise ConflictError("You already have an active trip", code="DRIVER_BUSY")

    active = await trip_service.get_active_trip_for_driver(driver_id)
    if active is not None:
        raise ConflictError("You already have an active trip", code="DRIVER_BUSY")

    offer = await get_trip_offer(trip_id)
    if offer is None:
        raise ConflictError("No active offer for this trip", code="NOT_YOUR_OFFER")

    if offer.get("driverId") != driver_id:
        raise ConflictError("This trip was offered to another driver", code="NOT_YOUR_OFFER")

    expires_raw = offer.get("expiresAt")
    if expires_raw:
        expires_at = datetime.fromisoformat(str(expires_raw).replace("Z", "+00:00"))
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if datetime.now(timezone.utc) >= expires_at:
            raise ConflictError("Offer has expired", code="OFFER_EXPIRED")


async def on_trip_accepted(trip_id: str, driver_id: str) -> None:
    await clear_trip_offer(trip_id)
    await set_driver_busy(driver_id, trip_id)
    await signal_dispatch_wake(trip_id)
    task = _dispatch_tasks.pop(trip_id, None)
    if task and not task.done():
        task.cancel()


async def on_trip_finished(driver_id: str) -> None:
    await clear_driver_busy(driver_id)


async def _wait_offer_window(trip_id: str, expires_at: datetime) -> str:
    """Wait until offer expires or dispatch is woken (reject/accept). Returns reason."""
    wake = _dispatch_wake.setdefault(trip_id, asyncio.Event())
    wake.clear()
    while True:
        remaining = (expires_at - datetime.now(timezone.utc)).total_seconds()
        if remaining <= 0:
            return "timeout"
        try:
            await asyncio.wait_for(wake.wait(), timeout=remaining)
        except asyncio.TimeoutError:
            return "timeout"
        current = await trip_service.get_trip_by_id(trip_id)
        if current.get("status") != "requested":
            return "accepted"
        offer = await get_trip_offer(trip_id)
        if offer is None:
            return "reject"
        # Spurious wake-up (e.g. from previous offer's redis publish event)
        wake.clear()


async def fail_trip_no_drivers(trip_id: str) -> None:
    """Cancel trip and notify client — safe to call multiple times."""
    current = await trip_service.get_trip_by_id(trip_id)
    if current.get("status") != "requested":
        return
    await clear_trip_offer(trip_id)
    await notify_no_drivers_found(trip_id)


async def on_client_cancelled_trip(trip_id: str, *, reason: str | None = None) -> None:
    """Client cancelled — stop dispatch, clear Redis offer, notify driver(s) with the card open."""
    trip = await trip_service.get_trip_by_id(trip_id)
    assigned_driver_id = trip.get("driverId")
    offer = await get_trip_offer(trip_id)
    offered_driver_id = (offer or {}).get("driverId") if offer else None

    notify_ids: set[str] = set()
    if assigned_driver_id:
        notify_ids.add(str(assigned_driver_id))
    if offered_driver_id:
        notify_ids.add(str(offered_driver_id))

    payload = {
        "tripId": trip_id,
        "reason": reason or "cancelled_by_client",
        "status": "cancelled",
    }
    for driver_id in notify_ids:
        await emit_to_driver(driver_id, "driver:trip_cancelled", payload)

    await clear_trip_offer(trip_id)

    if assigned_driver_id:
        await clear_driver_busy(str(assigned_driver_id))

    await signal_dispatch_wake(trip_id)
    task = _dispatch_tasks.pop(trip_id, None)
    if task and not task.done():
        task.cancel()


async def _dispatch_worker(trip: dict[str, Any], lock_token: str) -> None:
    trip_id = _trip_id_from_payload(trip)
    generation = 0
    try:
        current = await trip_service.get_trip_by_id(trip_id)
        if current.get("status") != "requested":
            return

        candidates = await find_dispatch_candidates(trip)
        if not candidates:
            deadline = (
                asyncio.get_running_loop().time()
                + settings.dispatch_no_candidate_grace_seconds
            )
            while asyncio.get_running_loop().time() < deadline:
                await asyncio.sleep(settings.dispatch_retry_interval_seconds)
                current = await trip_service.get_trip_by_id(trip_id)
                if current.get("status") != "requested":
                    return
                trip = await trip_service.trip_with_client(trip_id)
                candidates = await find_dispatch_candidates(trip)
                if candidates:
                    break
            if not candidates:
                await fail_trip_no_drivers(trip_id)
                return

        trip = await trip_service.trip_with_client(trip_id)
        candidate_index = 0

        for driver in candidates:
            try:
                driver_id = driver["id"]
                if await is_trip_rejected_by_driver(driver_id, trip_id):
                    continue

                current = await trip_service.get_trip_by_id(trip_id)
                if current.get("status") != "requested":
                    return

                generation += 1
                expires_at = await offer_to_driver(
                    trip,
                    driver,
                    candidate_index=candidate_index,
                    generation=generation,
                )
                candidate_index += 1

                reason = await _wait_offer_window(trip_id, expires_at)
                current = await trip_service.get_trip_by_id(trip_id)
                if current.get("status") != "requested":
                    await clear_trip_offer(trip_id)
                    return

                offer = await get_trip_offer(trip_id)
                if offer and offer.get("driverId") == driver_id:
                    await advance_offer(
                        trip_id,
                        reason if reason != "accepted" else "timeout",
                    )
            except Exception:
                logger.exception(
                    "dispatch candidate failed trip=%s driver=%s",
                    trip_id,
                    driver.get("id"),
                )
                await clear_trip_offer(trip_id)
                continue

        await fail_trip_no_drivers(trip_id)
    finally:
        await clear_trip_offer(trip_id)
        await release_dispatch_lock(trip_id, lock_token)
        _dispatch_tasks.pop(trip_id, None)
        _dispatch_wake.pop(trip_id, None)


async def start_dispatch(trip: dict[str, Any]) -> None:
    trip_id = _trip_id_from_payload(trip)
    if not trip_id:
        logger.warning("start_dispatch: missing trip id")
        return

    lock_token = secrets.token_hex(16)
    acquired = await acquire_dispatch_lock(
        trip_id,
        lock_token,
        settings.dispatch_lock_ttl_seconds,
    )
    if not acquired:
        logger.debug("start_dispatch: lock held for trip %s", trip_id)
        return

    existing = _dispatch_tasks.get(trip_id)
    if existing and not existing.done():
        await release_dispatch_lock(trip_id, lock_token)
        return

    task = asyncio.create_task(_dispatch_worker(trip, lock_token))
    _dispatch_tasks[trip_id] = task


async def advance_after_reject(trip_id: str, driver_id: str) -> None:
    """Advance dispatch after reject; idempotent if offer already cleared."""
    offer = await get_trip_offer(trip_id)
    if offer and offer.get("driverId") == driver_id:
        await advance_offer(trip_id, "reject")
        return
    if offer is None:
        await signal_dispatch_wake(trip_id)


async def build_current_offer_for_driver(driver_id: str) -> dict[str, Any] | None:
    trip_id = await get_driver_offer_trip_id(driver_id)
    if not trip_id:
        return None

    trip = await trip_service.get_trip_by_id(trip_id)
    if trip.get("status") != "requested":
        await clear_trip_offer(trip_id)
        return None

    offer = await get_trip_offer(trip_id)
    if not offer or offer.get("driverId") != driver_id:
        return None

    expires_raw = offer.get("expiresAt")
    if expires_raw:
        expires_at = datetime.fromisoformat(str(expires_raw).replace("Z", "+00:00"))
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if datetime.now(timezone.utc) >= expires_at:
            return None

    from app.services.trip_service import _get_client_info, _json_safe, _trip_route_metrics

    client = await _get_client_info(trip.get("clientId", ""))
    route_km, route_minutes = _trip_route_metrics(
        trip.get("pickup"),
        trip.get("dropoff"),
        stored_distance_km=trip.get("distanceKm"),
        stored_minutes=trip.get("estimatedMinutes"),
    )
    return {
        "id": trip_id,
        "tripId": trip_id,
        "pickup": trip.get("pickup"),
        "dropoff": trip.get("dropoff"),
        "fare": trip.get("fare"),
        "distanceKm": route_km,
        "estimatedDurationMinutes": route_minutes,
        "expiresAt": expires_raw,
        "offeredAt": offer.get("offeredAt") or expires_raw,
        "offerGeneration": offer.get("generation"),
        "clientName": client.get("name"),
        "clientPhone": client.get("phone"),
        "truckType": trip.get("truckType"),
        "client": {
            "name": client.get("name"),
            "phone": client.get("phone"),
        },
        "createdAt": _json_safe(trip.get("createdAt")),
    }
