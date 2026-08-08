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


def tashila_dynamic_fare(distance_km: float, duration_minutes: float) -> int:
    """Tashila dynamic fare with ceil-to-100 DZD rounding."""
    raw = (
        1000
        + max(0.0, distance_km - 5.0) * 100.0
        + max(0.0, duration_minutes - 60.0) * 20.0
    )
    return int(math.ceil(raw / 100.0) * 100)


def _default_settings() -> dict[str, Any]:
    return {
        "_id": SETTINGS_ID,
        "commissionRate": DEFAULT_COMMISSION_RATE,
        "serviceAreaCenter": DEFAULT_CENTER,
        "serviceAreaRadiusKm": DEFAULT_RADIUS_KM,
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
