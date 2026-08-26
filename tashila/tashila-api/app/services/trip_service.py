from datetime import datetime, timezone
from typing import Any

from bson import ObjectId
from bson.errors import InvalidId
from pymongo import ReturnDocument

from app.core.config import settings
from app.core.database import get_database
from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError, ValidationError
from app.core.redis import add_rejected_trip, get_rejected_trip_ids, publish
from app.models.trip import (
    AdminTripDispatchRequest,
    TripCoord,
    TripCreateRequest,
)
from app.services.driver_service import VALID_TRUCK_TYPES
from app.services.notification_service import (
    push_trip_accepted,
    push_trip_completed,
    push_trip_heading_to_pickup,
    push_trip_started,
)
from app.services.platform_settings_service import (
    get_commission_rate,
    validate_coords_in_service_area,
)
from app.services.pricing_service import tashila_dynamic_fare
from app.utils.geo import estimate_minutes, haversine_km
from app.utils.pagination import paginate, paginated_response

TRIPS_COLLECTION = "trips"
USERS_COLLECTION = "users"
DRIVERS_COLLECTION = "drivers"

ACTIVE_CLIENT_STATUSES = frozenset(
    {"requested", "accepted", "headingToPickup", "inProgress", "awaitingCash"},
)
CLIENT_CANCELLABLE_STATUSES = frozenset({"requested", "accepted"})
DRIVER_CANCELLABLE_STATUSES = frozenset({"accepted", "headingToPickup", "inProgress"})

DRIVER_ACTIVE_TRIP_STATUSES = frozenset(
    {"accepted", "headingToPickup", "inProgress", "awaitingCash"},
)

VALID_CANCEL_REASONS = frozenset(
    {"changed_plans", "wrong_address", "found_alternative", "driver_too_long", "other"},
)

DRIVER_STATUS_TRANSITIONS: dict[str, str] = {
    "accepted": "headingToPickup",
    "headingToPickup": "inProgress",
    "inProgress": "awaitingCash",
    "awaitingCash": "completed",
}

GEO_MAX_DISTANCE_METERS = 50_000


def _serialize_doc(doc: dict[str, Any]) -> dict[str, Any]:
    if doc.get("_id") is not None and not isinstance(doc["_id"], str):
        doc["_id"] = str(doc["_id"])
    if "id" not in doc and "_id" in doc:
        doc["id"] = doc["_id"]
    return doc


def _json_safe(value: Any) -> Any:
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, dict):
        return {k: _json_safe(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_json_safe(v) for v in value]
    if isinstance(value, ObjectId):
        return str(value)
    return value


def _pickup_location(pickup: TripCoord | dict[str, Any]) -> dict[str, Any]:
    if isinstance(pickup, TripCoord):
        lat, lng = pickup.lat, pickup.lng
    else:
        lat, lng = pickup["lat"], pickup["lng"]
    return {"type": "Point", "coordinates": [lng, lat]}


def _coord_dict(value: TripCoord | dict[str, Any] | None) -> dict[str, Any]:
    if value is None:
        return {}
    if isinstance(value, TripCoord):
        return value.model_dump()
    return value


def _trip_route_metrics(
    pickup: TripCoord | dict[str, Any] | None,
    dropoff: TripCoord | dict[str, Any] | None,
    *,
    stored_distance_km: float | None = None,
    stored_minutes: int | None = None,
) -> tuple[float, int]:
    """Return pickup→dropoff distance (km) and estimated duration (minutes)."""
    pickup_dict = _coord_dict(pickup)
    dropoff_dict = _coord_dict(dropoff)
    if stored_distance_km is not None and stored_distance_km > 0:
        distance_km = float(stored_distance_km)
    elif pickup_dict and dropoff_dict:
        distance_km = haversine_km(
            float(pickup_dict["lat"]),
            float(pickup_dict["lng"]),
            float(dropoff_dict["lat"]),
            float(dropoff_dict["lng"]),
        )
    else:
        distance_km = 0.0

    if stored_minutes is not None and stored_minutes > 0:
        minutes = int(stored_minutes)
    else:
        minutes = estimate_minutes(distance_km)

    return round(distance_km, 1), minutes


async def _find_trip(trip_id: str) -> dict[str, Any] | None:
    try:
        trip_oid = ObjectId(trip_id)
    except (InvalidId, TypeError):
        return None
    doc = await get_database()[TRIPS_COLLECTION].find_one({"_id": trip_oid})
    if doc is None:
        return None
    return _serialize_doc(doc)


async def _find_driver(driver_id: str) -> dict[str, Any] | None:
    try:
        oid = ObjectId(driver_id)
    except (InvalidId, TypeError):
        return None
    doc = await get_database()[DRIVERS_COLLECTION].find_one({"_id": oid})
    if doc is None:
        return None
    return _serialize_doc(doc)


def _is_driver_principal(principal: dict[str, Any]) -> bool:
    return "approvalStatus" in principal


async def _get_client_info(client_id: str) -> dict[str, Any]:
    if not client_id:
        return {}
    try:
        user_oid = ObjectId(client_id)
    except (InvalidId, TypeError):
        return {"id": client_id}
    user = await get_database()[USERS_COLLECTION].find_one({"_id": user_oid})
    if user is None:
        return {"id": client_id}

    rating = user.get("rating")
    if rating is None:
        try:
            pipeline = [
                {"$match": {"clientId": client_id, "clientRating": {"$ne": None}}},
                {"$group": {"_id": None, "avgRating": {"$avg": "$clientRating"}}},
            ]
            agg = await get_database()[TRIPS_COLLECTION].aggregate(pipeline).to_list(1)
            if agg and agg[0].get("avgRating") is not None:
                rating = round(float(agg[0]["avgRating"]), 2)
            else:
                rating = 5.0
        except Exception:
            rating = 5.0

    name = user.get("name")
    if not name:
        name = f"{user.get('firstName') or ''} {user.get('lastName') or ''}".strip()

    return {
        "id": str(user["_id"]),
        "phone": user.get("phone"),
        "name": name,
        "avatarUrl": user.get("avatarUrl"),
        "rating": rating,
    }


async def _get_driver_info(driver_id: str | None) -> dict[str, Any] | None:
    if not driver_id:
        return None
    driver = await _find_driver(driver_id)
    if driver is None:
        return None
    return {
        "id": driver["id"],
        "phone": driver.get("phone"),
        "name": driver.get("name"),
        "avatarUrl": driver.get("avatarUrl"),
        "truckType": driver.get("truckType"),
        "vehiclePlate": driver.get("vehiclePlate"),
        "vehicleColor": driver.get("vehicleColor"),
        "vehicleModel": driver.get("vehicleModel"),
        "rating": driver.get("rating"),
    }


async def _notify_client_status_push(trip: dict[str, Any], new_status: str) -> None:
    client_id = trip.get("clientId")
    if not client_id:
        return

    trip_id = str(trip.get("id") or trip.get("_id", ""))
    driver_id = trip.get("driverId")

    if new_status == "accepted":
        driver = await _get_driver_info(driver_id)
        driver_name = (driver or {}).get("name") or "Your driver"
        await push_trip_accepted(client_id, driver_name, trip_id)
    elif new_status == "headingToPickup":
        await push_trip_heading_to_pickup(client_id, trip_id)
    elif new_status == "inProgress":
        await push_trip_started(client_id, trip_id)
    elif new_status == "completed" and driver_id:
        await push_trip_completed(client_id, driver_id, trip_id)


async def _apply_trip_completion_earnings(driver_id: str, fare: float) -> None:
    commission_rate = await get_commission_rate()
    platform_due = fare * commission_rate
    now = datetime.now(timezone.utc)
    await get_database()[DRIVERS_COLLECTION].update_one(
        {"_id": ObjectId(driver_id)},
        {
            "$inc": {
                "earnings.totalEarnedDzd": fare,
                "earnings.platformDueDzd": platform_due,
            },
            "$set": {"updatedAt": now},
        },
    )


# --- Client actions ---


def _validate_truck_type(truck_type: str) -> None:
    if truck_type not in VALID_TRUCK_TYPES:
        raise ValidationError(
            f"Invalid truck type. Allowed: {', '.join(sorted(VALID_TRUCK_TYPES))}",
        )


def _normalize_cancel_reason(reason: str | None) -> str | None:
    if reason is None or not reason.strip():
        return None
    key = reason.strip()
    if key not in VALID_CANCEL_REASONS:
        raise ValidationError(
            f"Invalid cancel reason. Allowed: {', '.join(sorted(VALID_CANCEL_REASONS))}",
        )
    return key


async def estimate_trip(
    pickup: TripCoord,
    dropoff: TripCoord,
    truck_type: str,
    bypass_service_area: bool = False,
) -> dict[str, Any]:
    _validate_truck_type(truck_type)
    if not bypass_service_area:
        await validate_coords_in_service_area(
            pickup.lat, pickup.lng, dropoff.lat, dropoff.lng,
        )
    dist = haversine_km(pickup.lat, pickup.lng, dropoff.lat, dropoff.lng)
    minutes = estimate_minutes(dist)

    # Fetch pricing rules from DB
    pricing_collection = get_database()["pricing"]
    rule = await pricing_collection.find_one({"truckType": truck_type})
    if rule:
        base_fare = rule.get("baseFareDzd", 1000.0)
        price_per_km = rule.get("pricePerKmDzd", 100.0)
    else:
        base_fare = 1000.0
        price_per_km = 100.0

    raw_fare = base_fare + price_per_km * dist
    import math
    fare = int(math.ceil(raw_fare / 100.0) * 100)

    return {
        "distanceKm": round(dist, 1),
        "estimatedMinutes": minutes,
        "fare": fare,
        "currency": "DZD",
    }


async def create_trip(
    client_id: str,
    data: TripCreateRequest,
    *,
    idempotency_key: str | None = None,
) -> dict[str, Any]:
    from app.core.redis import get_redis

    redis = get_redis()
    if idempotency_key:
        cache_key = f"idempotency:trip:{client_id}:{idempotency_key}"
        cached = await redis.get(cache_key)
        if cached:
            import json

            return json.loads(cached)

    collection = get_database()[TRIPS_COLLECTION]
    active = await collection.find_one(
        {"clientId": client_id, "status": {"$in": list(ACTIVE_CLIENT_STATUSES)}},
    )
    if active is not None:
        raise ConflictError("You already have an active trip")

    last_trip = await collection.find_one(
        {"clientId": client_id},
        sort=[("updatedAt", -1)],
    )
    if last_trip is not None:
        status = last_trip.get("status")
        has_rating = last_trip.get("driverRating") is not None
        if status == "completed" and not has_rating:
            raise ConflictError(
                "Please rate your last trip before booking a new one",
                code="rating_required",
            )

    _validate_truck_type(data.truckType)
    estimate = await estimate_trip(data.pickup, data.dropoff, data.truckType)
    now = datetime.now(timezone.utc)
    doc = {
        "status": "requested",
        "clientId": client_id,
        "driverId": None,
        "pickup": data.pickup.model_dump(),
        "dropoff": data.dropoff.model_dump(),
        "pickupLocation": _pickup_location(data.pickup),
        "truckType": data.truckType,
        "fare": float(estimate["fare"]),
        "distanceKm": float(estimate["distanceKm"]),
        "estimatedMinutes": int(estimate["estimatedMinutes"]),
        "finalFare": None,
        "paymentMethod": data.paymentMethod,
        "notes": data.notes,
        "driverRating": None,
        "clientRating": None,
        "clientRatingComment": None,
        "driverRatingComment": None,
        "cancelledReason": None,
        "createdAt": now,
        "updatedAt": now,
        "completedAt": None,
    }
    result = await collection.insert_one(doc)
    trip_id = str(result.inserted_id)
    doc["_id"] = trip_id
    serialized = _serialize_doc(doc)

    client_info = await _get_client_info(client_id)
    trip_payload = {**serialized, "client": client_info}

    from app.services import dispatch_service

    trip_full = await trip_with_client(trip_id)
    nearby_count = len(await dispatch_service.find_dispatch_candidates(trip_full))

    if nearby_count == 0:
        await dispatch_service.fail_trip_no_drivers(trip_id)
        cancelled = await get_trip_by_id(trip_id)
        response = {
            "trip": {
                "id": trip_id,
                "status": cancelled.get("status", "cancelled"),
                "cancelledReason": cancelled.get("cancelledReason", "no_drivers_found"),
                "fare": serialized["fare"],
                "createdAt": _json_safe(now),
            },
            "dispatch": {
                "nearbyDriversCount": 0,
                "started": False,
                "outcome": "no_drivers_found",
            },
        }
        if idempotency_key:
            import json

            await redis.set(
                f"idempotency:trip:{client_id}:{idempotency_key}",
                json.dumps(response),
                ex=86400,
            )
        return response

    await publish("trip:new", _json_safe(trip_payload))
    await dispatch_service.start_dispatch(trip_full)

    response = {
        "trip": {
            "id": trip_id,
            "status": "requested",
            "fare": serialized["fare"],
            "createdAt": _json_safe(now),
        },
        "dispatch": {
            "nearbyDriversCount": nearby_count,
            "started": True,
            "outcome": "searching",
        },
    }
    if idempotency_key:
        import json

        await redis.set(
            f"idempotency:trip:{client_id}:{idempotency_key}",
            json.dumps(response),
            ex=86400,
        )
    return response


def _pending_client_rating_filter() -> dict[str, Any]:
    return {
        "status": "completed",
        "$or": [{"clientRating": None}, {"clientRating": {"$exists": False}}],
    }


def _pending_driver_rating_filter() -> dict[str, Any]:
    return {
        "status": "completed",
        "$or": [{"driverRating": None}, {"driverRating": {"$exists": False}}],
    }


async def get_active_trip_for_driver(driver_id: str) -> dict[str, Any] | None:
    doc = await get_database()[TRIPS_COLLECTION].find_one(
        {"driverId": driver_id},
        sort=[("updatedAt", -1)],
    )
    if doc is None:
        return None

    status = doc.get("status")
    has_rating = doc.get("clientRating") is not None
    is_active = status in DRIVER_ACTIVE_TRIP_STATUSES
    is_pending_rating = status == "completed" and not has_rating

    if is_active or is_pending_rating:
        serialized = _serialize_doc(doc)
        client_info = await _get_client_info(serialized.get("clientId", ""))
        if serialized.get("externalLabel"):
            client_info["name"] = serialized.get("externalLabel")
        if serialized.get("externalPhone"):
            client_info["phone"] = serialized.get("externalPhone")
        return {**serialized, "client": client_info}
    return None


async def get_active_trip_for_client(client_id: str) -> dict[str, Any] | None:
    doc = await get_database()[TRIPS_COLLECTION].find_one(
        {"clientId": client_id},
        sort=[("updatedAt", -1)],
    )
    if doc is None:
        return None

    status = doc.get("status")
    has_rating = doc.get("driverRating") is not None
    is_active = status in ACTIVE_CLIENT_STATUSES
    is_pending_rating = status == "completed" and not has_rating

    if is_active or is_pending_rating:
        serialized = _serialize_doc(doc)
        driver_info = await _get_driver_info(serialized.get("driverId"))
        if driver_info:
            return {**serialized, "driver": driver_info}
        return serialized
    return None


async def get_trip_by_id(trip_id: str) -> dict[str, Any]:
    trip = await _find_trip(trip_id)
    if trip is None:
        raise NotFoundError("Trip not found")
    return trip


async def trip_with_client(trip_id: str) -> dict[str, Any]:
    trip = await get_trip_by_id(trip_id)
    client_info = await _get_client_info(trip.get("clientId", ""))
    if trip.get("externalLabel"):
        client_info["name"] = trip.get("externalLabel")
    if trip.get("externalPhone"):
        client_info["phone"] = trip.get("externalPhone")
    return {**trip, "client": client_info}


async def cancel_trip_no_driver(trip_id: str) -> dict[str, Any]:
    trip = await _find_trip(trip_id)
    if trip is None:
        raise NotFoundError("Trip not found")
    if trip.get("status") != "requested":
        return trip

    now = datetime.now(timezone.utc)
    await get_database()[TRIPS_COLLECTION].update_one(
        {"_id": ObjectId(trip_id)},
        {
            "$set": {
                "status": "cancelled",
                "cancelledReason": "no_drivers_found",
                "updatedAt": now,
            },
        },
    )
    return await _find_trip(trip_id)  # type: ignore[return-value]


async def cancel_trip(trip_id: str, client_id: str, reason: str | None = None) -> dict[str, Any]:
    from app.core.redis import get_trip_offer
    from app.services import dispatch_service

    normalized_reason = _normalize_cancel_reason(reason)

    trip = await _find_trip(trip_id)
    if trip is None:
        raise NotFoundError("Trip not found")
    if trip.get("clientId") != client_id:
        raise ForbiddenError("You do not have access to this trip")
    if trip.get("status") not in CLIENT_CANCELLABLE_STATUSES:
        raise ConflictError("Cannot cancel after driver is en route")

    offer = await get_trip_offer(trip_id)
    offered_driver_id = (offer or {}).get("driverId") if offer else None
    assigned_driver_id = trip.get("driverId")

    now = datetime.now(timezone.utc)
    await get_database()[TRIPS_COLLECTION].update_one(
        {"_id": ObjectId(trip_id)},
        {"$set": {"status": "cancelled", "cancelledReason": normalized_reason, "updatedAt": now}},
    )

    await dispatch_service.on_client_cancelled_trip(trip_id, reason=normalized_reason)

    notify_driver_ids: set[str] = set()
    if assigned_driver_id:
        notify_driver_ids.add(str(assigned_driver_id))
    if offer:
        offered_driver_id = offer.get("driverId")
        if offered_driver_id:
            notify_driver_ids.add(str(offered_driver_id))
        offered_driver_ids = offer.get("driverIds", [])
        for d_id in offered_driver_ids:
            notify_driver_ids.add(str(d_id))

    for d_id in notify_driver_ids:
        await publish(
            "trip:cancelled_by_client",
            _json_safe(
                {
                    "tripId": trip_id,
                    "driverId": d_id,
                    "reason": normalized_reason,
                },
            ),
        )

    from app.socket.client_handlers import notify_trip_status_changed

    await notify_trip_status_changed(
        trip_id,
        "cancelled",
        extra={"cancelledReason": normalized_reason},
    )

    return await _find_trip(trip_id)  # type: ignore[return-value]


async def rate_driver(
    trip_id: str,
    client_id: str,
    rating: int,
    comment: str | None,
) -> dict[str, Any]:
    trip = await _find_trip(trip_id)
    if trip is None:
        raise NotFoundError("Trip not found")
    if trip.get("clientId") != client_id:
        raise ForbiddenError("You do not have access to this trip")
    if trip.get("status") not in ("completed", "awaitingCash"):
        raise ConflictError("Trip must be completed or awaiting cash before rating")
    if trip.get("driverRating") is not None:
        raise ConflictError("Driver already rated for this trip")

    driver_id = trip.get("driverId")
    if not driver_id:
        raise ConflictError("Trip has no assigned driver")

    now = datetime.now(timezone.utc)
    await get_database()[TRIPS_COLLECTION].update_one(
        {"_id": ObjectId(trip_id)},
        {"$set": {"driverRating": rating, "driverRatingComment": comment, "updatedAt": now}},
    )

    pipeline = [
        {"$match": {"driverId": driver_id, "driverRating": {"$ne": None}}},
        {"$group": {"_id": None, "avgRating": {"$avg": "$driverRating"}}},
    ]
    agg = await get_database()[TRIPS_COLLECTION].aggregate(pipeline).to_list(1)
    if agg:
        await get_database()[DRIVERS_COLLECTION].update_one(
            {"_id": ObjectId(driver_id)},
            {"$set": {"rating": round(agg[0]["avgRating"], 2), "updatedAt": now}},
        )

    return await _find_trip(trip_id)  # type: ignore[return-value]


async def get_trip_for_principal(trip_id: str, principal: dict[str, Any]) -> dict[str, Any]:
    trip = await _find_trip(trip_id)
    if trip is None:
        raise NotFoundError("Trip not found")

    principal_id = principal["id"]
    if _is_driver_principal(principal):
        if trip.get("driverId") != principal_id:
            raise ForbiddenError("You do not have access to this trip")
    elif trip.get("clientId") != principal_id:
        raise ForbiddenError("You do not have access to this trip")

    driver_info = await _get_driver_info(trip.get("driverId"))
    if driver_info:
        trip = {**trip, "driver": driver_info}
    return trip


# --- Driver actions ---


async def get_current_offer_for_driver(driver_id: str) -> dict[str, Any] | None:
    from app.services import dispatch_service

    return await dispatch_service.build_current_offer_for_driver(driver_id)


async def get_trip_requests_for_driver(driver_id: str) -> list[dict[str, Any]]:
    """Exclusive dispatch: at most one trip when this driver holds the active offer."""
    offer = await get_current_offer_for_driver(driver_id)
    if offer is None:
        return []
    return [offer]


async def accept_trip(trip_id: str, driver_id: str) -> dict[str, Any]:
    from app.services import dispatch_service

    await dispatch_service.validate_accept(trip_id, driver_id)

    try:
        trip_oid = ObjectId(trip_id)
    except (InvalidId, TypeError) as exc:
        raise NotFoundError("Trip not found") from exc

    now = datetime.now(timezone.utc)
    updated = await get_database()[TRIPS_COLLECTION].find_one_and_update(
        {"_id": trip_oid, "status": "requested"},
        {
            "$set": {
                "status": "accepted",
                "driverId": driver_id,
                "updatedAt": now,
            },
        },
        return_document=ReturnDocument.AFTER,
    )
    if updated is None:
        raise ConflictError("Trip already taken", code="TRIP_NOT_AVAILABLE")

    await dispatch_service.on_trip_accepted(trip_id, driver_id)

    serialized = _serialize_doc(updated)
    await publish(
        "trip:accepted",
        _json_safe({"tripId": trip_id, "driverId": driver_id}),
    )
    await _notify_client_status_push(serialized, "accepted")

    return serialized


async def reject_trip(trip_id: str, driver_id: str) -> None:
    from app.services import dispatch_service

    await dispatch_service.validate_reject(trip_id, driver_id)
    await add_rejected_trip(driver_id, trip_id, ttl_seconds=settings.reject_ttl_seconds)
    await dispatch_service.advance_after_reject(trip_id, driver_id)
    await publish(
        "trip:rejected_by_driver",
        _json_safe({"tripId": trip_id, "driverId": driver_id}),
    )


async def _verify_driver_assigned(trip: dict[str, Any], driver_id: str) -> None:
    if trip.get("driverId") != driver_id:
        raise ForbiddenError("You are not assigned to this trip")


async def calculate_final_fare_for_trip(trip: dict[str, Any], started_at: datetime | None, completed_at: datetime) -> float:
    from app.services.platform_settings_service import get_platform_settings
    settings_doc = await get_platform_settings()
    wait_grace_minutes = float(settings_doc.get("waitGraceMinutes", 5.0))
    wait_minute_price = float(settings_doc.get("waitMinutePriceDzd", 25.0))

    estimated_eta = float(trip.get("estimatedMinutes") or 0)
    if started_at:
        actual_time = (completed_at.timestamp() - started_at.timestamp()) / 60.0
    else:
        actual_time = estimated_eta
    allowed_time = estimated_eta + wait_grace_minutes
    extra_time = max(0.0, actual_time - allowed_time)
    time_fare = extra_time * wait_minute_price

    pricing_collection = get_database()["pricing"]
    rule = await pricing_collection.find_one({"truckType": trip.get("truckType")})
    base_fare = rule.get("baseFareDzd", 1000.0) if rule else 1000.0
    price_per_km = rule.get("pricePerKmDzd", 100.0) if rule else 100.0
    distance_km = float(trip.get("distanceKm") or 0.0)
    distance_fare = price_per_km * distance_km

    subtotal = (base_fare + distance_fare + time_fare) * 1.0 + 0.0
    raw_fare = max(base_fare, subtotal)
    import math
    return float(math.ceil(raw_fare / 100.0) * 100)


async def advance_trip_status(trip_id: str, driver_id: str, new_status: str) -> dict[str, Any]:
    trip = await _find_trip(trip_id)
    if trip is None:
        raise NotFoundError("Trip not found")
    await _verify_driver_assigned(trip, driver_id)

    current = trip.get("status")
    expected_next = DRIVER_STATUS_TRANSITIONS.get(current)
    if expected_next != new_status:
        raise ConflictError(f"Invalid status transition from '{current}' to '{new_status}'")

    now = datetime.now(timezone.utc)
    updates: dict[str, Any] = {"status": new_status, "updatedAt": now}
    if new_status == "inProgress":
        updates["startedAt"] = now
    if new_status == "awaitingCash":
        updates["completedAt"] = now
        started_at = trip.get("startedAt")
        updates["finalFare"] = await calculate_final_fare_for_trip(trip, started_at, now)
    if new_status == "completed":
        fare = float(trip.get("finalFare") or trip.get("fare") or 0)
        await _apply_trip_completion_earnings(driver_id, fare)
        from app.services import dispatch_service

        await dispatch_service.on_trip_finished(driver_id)

    await get_database()[TRIPS_COLLECTION].update_one(
        {"_id": ObjectId(trip_id)},
        {"$set": updates},
    )
    await publish(
        "trip:status_changed",
        _json_safe({"tripId": trip_id, "status": new_status, "driverId": driver_id}),
    )
    updated = await _find_trip(trip_id)
    if updated:
        await _notify_client_status_push(updated, new_status)
    return updated  # type: ignore[return-value]


async def rate_client(trip_id: str, driver_id: str, rating: int, comment: str | None = None) -> dict[str, Any]:
    trip = await _find_trip(trip_id)
    if trip is None:
        raise NotFoundError("Trip not found")
    await _verify_driver_assigned(trip, driver_id)
    if trip.get("status") != "completed":
        raise ConflictError("Trip must be completed before rating")
    if trip.get("clientRating") is not None:
        raise ConflictError("Client already rated for this trip")

    now = datetime.now(timezone.utc)
    await get_database()[TRIPS_COLLECTION].update_one(
        {"_id": ObjectId(trip_id)},
        {
            "$set": {
                "clientRating": rating,
                "clientRatingComment": comment,
                "updatedAt": now,
            },
        },
    )

    client_id = trip.get("clientId")
    if client_id:
        try:
            pipeline = [
                {"$match": {"clientId": client_id, "clientRating": {"$ne": None}}},
                {"$group": {"_id": None, "avgRating": {"$avg": "$clientRating"}}},
            ]
            agg = await get_database()[TRIPS_COLLECTION].aggregate(pipeline).to_list(1)
            if agg:
                await get_database()[USERS_COLLECTION].update_one(
                    {"_id": ObjectId(client_id)},
                    {"$set": {"rating": round(agg[0]["avgRating"], 2), "updatedAt": now}},
                )
        except Exception:
            pass

    return await _find_trip(trip_id)  # type: ignore[return-value]


async def driver_cancel_trip(trip_id: str, driver_id: str, reason: str | None = None) -> dict[str, Any]:
    from app.services import dispatch_service
    from app.socket.client_handlers import notify_trip_status_changed

    trip = await _find_trip(trip_id)
    if trip is None:
        raise NotFoundError("Trip not found")
    await _verify_driver_assigned(trip, driver_id)
    if trip.get("status") not in DRIVER_CANCELLABLE_STATUSES:
        raise ConflictError("Cannot cancel trip at this stage")

    normalized_reason = _normalize_cancel_reason(reason) or "driver_cancelled"
    now = datetime.now(timezone.utc)
    await get_database()[TRIPS_COLLECTION].update_one(
        {"_id": ObjectId(trip_id)},
        {
            "$set": {
                "status": "cancelled",
                "cancelledReason": normalized_reason,
                "updatedAt": now,
            },
        },
    )

    await dispatch_service.on_trip_finished(driver_id)
    await publish(
        "trip:status_changed",
        _json_safe({
            "tripId": trip_id,
            "status": "cancelled",
            "driverId": driver_id,
            "cancelledReason": normalized_reason,
        }),
    )
    await notify_trip_status_changed(
        trip_id,
        "cancelled",
        extra={"cancelledReason": normalized_reason},
    )
    return await _find_trip(trip_id)  # type: ignore[return-value]


# --- Admin actions ---


def _parse_datetime(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ValidationError(f"Invalid datetime: {value}") from exc


async def admin_list_trips(
    *,
    status: str | None = None,
    driver_id: str | None = None,
    client_id: str | None = None,
    from_dt: str | None = None,
    to_dt: str | None = None,
    page: int = 1,
    limit: int = 20,
) -> dict[str, Any]:
    query: dict[str, Any] = {}
    if status:
        query["status"] = status
    if driver_id:
        query["driverId"] = driver_id
    if client_id:
        query["clientId"] = client_id

    created_filter: dict[str, Any] = {}
    parsed_from = _parse_datetime(from_dt)
    parsed_to = _parse_datetime(to_dt)
    if parsed_from:
        created_filter["$gte"] = parsed_from
    if parsed_to:
        created_filter["$lte"] = parsed_to
    if created_filter:
        query["createdAt"] = created_filter

    params = paginate(page, limit)
    collection = get_database()[TRIPS_COLLECTION]
    total = await collection.count_documents(query)
    cursor = (
        collection.find(query)
        .sort("createdAt", -1)
        .skip(params["skip"])
        .limit(params["limit"])
    )
    items_raw = [_serialize_doc(doc) async for doc in cursor]

    # Enrich each trip with client and driver name
    driver_cache: dict[str, str | None] = {}
    client_cache: dict[str, str | None] = {}
    client_phone_cache: dict[str, str | None] = {}
    enriched_items = []
    for item in items_raw:
        # Driver Name
        driver_id = item.get("driverId")
        if driver_id:
            driver_str = str(driver_id)
            if driver_str not in driver_cache:
                try:
                    oid = ObjectId(driver_str)
                    driver_doc = await get_database()[DRIVERS_COLLECTION].find_one(
                        {"_id": oid}, {"name": 1}
                    )
                    driver_cache[driver_str] = (driver_doc or {}).get("name")
                except Exception:
                    driver_cache[driver_str] = None
            item["driverName"] = driver_cache.get(driver_str)

        # Client Name & Phone
        client_id = item.get("clientId")
        if client_id:
            client_str = str(client_id)
            if client_str not in client_cache:
                try:
                    oid = ObjectId(client_str)
                    client_doc = await get_database()[USERS_COLLECTION].find_one(
                        {"_id": oid}, {"firstName": 1, "lastName": 1, "name": 1, "phone": 1}
                    )
                    if client_doc:
                        name = client_doc.get("name")
                        if not name:
                            name = f"{client_doc.get('firstName') or ''} {client_doc.get('lastName') or ''}".strip()
                        client_cache[client_str] = name
                        client_phone_cache[client_str] = client_doc.get("phone")
                    else:
                        client_cache[client_str] = None
                        client_phone_cache[client_str] = None
                except Exception:
                    client_cache[client_str] = None
                    client_phone_cache[client_str] = None
            item["clientName"] = client_cache.get(client_str)
            item["clientPhone"] = item.get("externalPhone") or client_phone_cache.get(client_str)
        else:
            item["clientPhone"] = item.get("externalPhone")

        enriched_items.append(item)

    return paginated_response(enriched_items, total, params["page"], params["limit"])


async def admin_get_trip(trip_id: str) -> dict[str, Any]:
    trip = await _find_trip(trip_id)
    if trip is None:
        raise NotFoundError("Trip not found")
    client_info = await _get_client_info(trip.get("clientId", ""))
    if trip.get("externalLabel"):
        client_info["name"] = trip.get("externalLabel")
    if trip.get("externalPhone"):
        client_info["phone"] = trip.get("externalPhone")
    result: dict[str, Any] = {
        **trip,
        "client": client_info,
        "driver": await _get_driver_info(trip.get("driverId")),
    }
    if trip.get("status") == "requested":
        from app.core.redis import get_trip_offer

        offer = await get_trip_offer(trip_id)
        if offer:
            result["dispatchOffer"] = {
                **offer,
                "driver": await _get_driver_info(offer.get("driverId")),
            }
    return result


async def admin_dispatch_trip(data: AdminTripDispatchRequest) -> dict[str, Any]:
    from app.core.redis import is_driver_busy
    from app.services import dispatch_service

    _validate_truck_type(data.truckType)
    driver = await _find_driver(data.driverId)
    if driver is None:
        raise NotFoundError("Driver not found")
    if driver.get("truckType") != data.truckType:
        raise ValidationError("Driver truck type does not match trip truck type")
    if await is_driver_busy(data.driverId):
        raise ConflictError("Driver is busy with another trip")
    active = await get_active_trip_for_driver(data.driverId)
    if active is not None:
        raise ConflictError("Driver already has an active trip")

    estimate = await estimate_trip(data.pickup, data.dropoff, data.truckType, bypass_service_area=True)
    now = datetime.now(timezone.utc)
    client_id = data.clientId or ""
    notes = data.notes
    if data.externalLabel:
        external_note = f"External order: {data.externalLabel}"
        notes = f"{notes}\n{external_note}" if notes else external_note

    dispatch_mode = getattr(data, "dispatchMode", "accepted")
    is_accepted = dispatch_mode == "accepted"

    doc = {
        "status": "accepted" if is_accepted else "requested",
        "clientId": client_id,
        "driverId": data.driverId if is_accepted else None,
        "targetedDriverId": None if is_accepted else data.driverId,
        "pickup": data.pickup.model_dump(),
        "dropoff": data.dropoff.model_dump(),
        "pickupLocation": _pickup_location(data.pickup),
        "truckType": data.truckType,
        "fare": float(estimate["fare"]),
        "distanceKm": float(estimate["distanceKm"]),
        "estimatedMinutes": int(estimate["estimatedMinutes"]),
        "finalFare": None,
        "paymentMethod": data.paymentMethod,
        "notes": notes,
        "externalLabel": data.externalLabel,
        "externalPhone": data.externalPhone,
        "driverRating": None,
        "clientRating": None,
        "clientRatingComment": None,
        "driverRatingComment": None,
        "cancelledReason": None,
        "createdAt": now,
        "updatedAt": now,
        "completedAt": None,
        "dispatchedByAdmin": True,
    }
    result = await get_database()[TRIPS_COLLECTION].insert_one(doc)
    trip_id = str(result.inserted_id)

    if is_accepted:
        await dispatch_service.on_trip_accepted(trip_id, data.driverId)
        await publish(
            "trip:accepted",
            _json_safe({"tripId": trip_id, "driverId": data.driverId, "dispatchedByAdmin": True}),
        )
        if client_id:
            dispatched = await _find_trip(trip_id)
            if dispatched:
                await _notify_client_status_push(dispatched, "accepted")
    else:
        doc["_id"] = trip_id
        serialized = _serialize_doc(doc)
        client_info = await _get_client_info(client_id)
        trip_payload = {**serialized, "client": client_info}
        await publish("trip:new", _json_safe(trip_payload))
        trip_full = await trip_with_client(trip_id)
        await dispatch_service.start_dispatch(trip_full)

    return await _find_trip(trip_id)  # type: ignore[return-value]


async def admin_force_status(trip_id: str, new_status: str) -> dict[str, Any]:
    trip = await _find_trip(trip_id)
    if trip is None:
        raise NotFoundError("Trip not found")

    current = trip.get("status")
    if new_status == "completed" and current == "completed":
        return trip

    now = datetime.now(timezone.utc)
    updates: dict[str, Any] = {"status": new_status, "updatedAt": now}
    if new_status == "completed" and current != "completed":
        updates["completedAt"] = now
        if trip.get("finalFare") is None:
            started_at = trip.get("startedAt")
            updates["finalFare"] = await calculate_final_fare_for_trip(trip, started_at, now)
        driver_id = trip.get("driverId")
        if driver_id:
            fare = float(trip.get("finalFare") or trip.get("fare") or 0)
            await _apply_trip_completion_earnings(driver_id, fare)
            from app.services import dispatch_service

            await dispatch_service.on_trip_finished(driver_id)

    await get_database()[TRIPS_COLLECTION].update_one(
        {"_id": ObjectId(trip_id)},
        {"$set": updates},
    )
    updated = await _find_trip(trip_id)
    if updated:
        await _notify_client_status_push(updated, new_status)
        await publish(
            "trip:status_changed",
            _json_safe({
                "tripId": trip_id,
                "status": new_status,
                "driverId": updated.get("driverId"),
            }),
        )
    return updated  # type: ignore[return-value]


async def admin_cash_confirm(trip_id: str) -> dict[str, Any]:
    trip = await _find_trip(trip_id)
    if trip is None:
        raise NotFoundError("Trip not found")
    if trip.get("status") != "awaitingCash":
        raise ConflictError("Trip must be in awaitingCash status")

    driver_id = trip.get("driverId")
    if not driver_id:
        raise ConflictError("Trip has no assigned driver")

    return await advance_trip_status(trip_id, driver_id, "completed")


async def admin_delete_trip(trip_id: str) -> dict[str, Any]:
    from app.services import dispatch_service

    trip = await _find_trip(trip_id)
    if trip is None:
        raise NotFoundError("Trip not found")

    now = datetime.now(timezone.utc)
    await get_database()[TRIPS_COLLECTION].update_one(
        {"_id": ObjectId(trip_id)},
        {
            "$set": {
                "status": "cancelled",
                "cancelledReason": "admin_deleted",
                "updatedAt": now,
            },
        },
    )
    await dispatch_service.on_client_cancelled_trip(trip_id, reason="admin_deleted")
    driver_id = trip.get("driverId")
    if driver_id:
        await dispatch_service.on_trip_finished(str(driver_id))
    return await _find_trip(trip_id)  # type: ignore[return-value]
