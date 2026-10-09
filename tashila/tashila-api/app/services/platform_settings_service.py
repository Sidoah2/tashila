import math
from datetime import datetime, timezone
from typing import Any

from app.core.database import get_database
from app.models.platform_settings import PlatformSettingsUpdate

SETTINGS_COLLECTION = "platform_settings"
SETTINGS_ID = "global"

DEFAULT_CENTER = {"lat": 22.785, "lng": 5.523}
DEFAULT_RADIUS_KM = 3000.0
DEFAULT_COMMISSION_RATE = 0.10


from app.services.pricing_service import tashila_dynamic_fare


def _default_settings() -> dict[str, Any]:
    return {
        "_id": SETTINGS_ID,
        "commissionRate": DEFAULT_COMMISSION_RATE,
        "serviceAreaCenter": DEFAULT_CENTER,
        "serviceAreaRadiusKm": DEFAULT_RADIUS_KM,
        "maxDispatchDistanceKm": 50.0,
        "waitGraceMinutes": 5.0,
        "waitMinutePriceDzd": 25.0,
        "updatedAt": datetime.now(timezone.utc),
    }


async def get_platform_settings() -> dict[str, Any]:
    doc = await get_database()[SETTINGS_COLLECTION].find_one({"_id": SETTINGS_ID})
    if doc is None:
        return _default_settings()
    return doc


async def update_platform_settings(data: PlatformSettingsUpdate) -> dict[str, Any]:
    current = await get_platform_settings()
    payload = data.model_dump(exclude_unset=True)
    updates: dict[str, Any] = {"updatedAt": datetime.now(timezone.utc)}
    if "commissionRate" in payload and payload["commissionRate"] is not None:
        updates["commissionRate"] = float(payload["commissionRate"])
    if "serviceAreaCenter" in payload and payload["serviceAreaCenter"] is not None:
        center = payload["serviceAreaCenter"]
        if hasattr(center, "model_dump"):
            center = center.model_dump()
        updates["serviceAreaCenter"] = center
    if "serviceAreaRadiusKm" in payload and payload["serviceAreaRadiusKm"] is not None:
        updates["serviceAreaRadiusKm"] = float(payload["serviceAreaRadiusKm"])
    if "maxDispatchDistanceKm" in payload and payload["maxDispatchDistanceKm"] is not None:
        updates["maxDispatchDistanceKm"] = float(payload["maxDispatchDistanceKm"])
    if "waitGraceMinutes" in payload and payload["waitGraceMinutes"] is not None:
        updates["waitGraceMinutes"] = float(payload["waitGraceMinutes"])
    if "waitMinutePriceDzd" in payload and payload["waitMinutePriceDzd"] is not None:
        updates["waitMinutePriceDzd"] = float(payload["waitMinutePriceDzd"])

    merged = {**current, **updates, "_id": SETTINGS_ID}
    await get_database()[SETTINGS_COLLECTION].update_one(
        {"_id": SETTINGS_ID},
        {"$set": merged},
        upsert=True,
    )
    return await get_platform_settings()


async def get_commission_rate() -> float:
    settings = await get_platform_settings()
    return float(settings.get("commissionRate", DEFAULT_COMMISSION_RATE))


def is_within_service_area(
    lat: float,
    lng: float,
    center: dict[str, float],
    radius_km: float,
) -> bool:
    from app.utils.geo import haversine_km

    dist = haversine_km(lat, lng, float(center["lat"]), float(center["lng"]))
    return dist <= radius_km


async def validate_coords_in_service_area(
    pickup_lat: float,
    pickup_lng: float,
    dropoff_lat: float,
    dropoff_lng: float,
) -> None:
    from app.core.exceptions import ConflictError

    settings = await get_platform_settings()
    center = settings.get("serviceAreaCenter") or DEFAULT_CENTER
    radius_km = float(settings.get("serviceAreaRadiusKm", DEFAULT_RADIUS_KM))

    pickup_ok = is_within_service_area(pickup_lat, pickup_lng, center, radius_km)
    dropoff_ok = is_within_service_area(dropoff_lat, dropoff_lng, center, radius_km)
    if not pickup_ok or not dropoff_ok:
        raise ConflictError(
            "Pickup or dropoff is outside the service area",
            code="service_area_unavailable",
        )
