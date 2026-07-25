import math
from datetime import datetime, timezone
from typing import Any

from app.core.database import get_database
from app.core.exceptions import NotFoundError
from app.models.pricing import PricingResponse, PricingUpdate


def tashila_dynamic_fare(distance_km: float, duration_minutes: float) -> int:
    """Tashila dynamic fare with ceil-to-100 DZD rounding."""
    raw = (
        1000
        + max(0.0, distance_km - 5.0) * 100.0
        + max(0.0, duration_minutes - 60.0) * 20.0
    )
    return int(math.ceil(raw / 100.0) * 100)

PRICING_COLLECTION = "pricing"


def _serialize_doc(doc: dict[str, Any]) -> dict[str, Any]:
    if doc.get("_id") is not None and not isinstance(doc["_id"], str):
        doc["_id"] = str(doc["_id"])
    if "id" not in doc and "_id" in doc:
        doc["id"] = doc["_id"]
    return doc


def _to_pricing_response(doc: dict[str, Any]) -> dict[str, Any]:
    return PricingResponse.model_validate(_serialize_doc(doc)).model_dump(by_alias=True)


async def get_all_pricing() -> list[dict[str, Any]]:
    collection = get_database()[PRICING_COLLECTION]
    cursor = collection.find({}).sort("truckType", 1)
    return [_to_pricing_response(doc) async for doc in cursor]


async def get_pricing_by_truck(truck_type: str) -> dict[str, Any]:
    doc = await get_database()[PRICING_COLLECTION].find_one({"truckType": truck_type})
    if doc is None:
        raise NotFoundError(f"Pricing not found for truck type: {truck_type}")
    return _to_pricing_response(doc)


async def update_pricing(truck_type: str, data: PricingUpdate) -> dict[str, Any]:
    now = datetime.now(timezone.utc)
    payload = data.model_dump(exclude_unset=True)
    set_fields: dict[str, Any] = {"truckType": truck_type, "updatedAt": now}
    if "label" in payload:
        set_fields["label"] = payload["label"]
    if "baseFareDzd" in payload:
        set_fields["baseFareDzd"] = payload["baseFareDzd"]
    if "pricePerKmDzd" in payload:
        set_fields["pricePerKmDzd"] = payload["pricePerKmDzd"]

    collection = get_database()[PRICING_COLLECTION]
    await collection.update_one(
        {"truckType": truck_type},
        {"$set": set_fields},
        upsert=True,
    )
    doc = await collection.find_one({"truckType": truck_type})
    return _to_pricing_response(doc)  # type: ignore[arg-type]
