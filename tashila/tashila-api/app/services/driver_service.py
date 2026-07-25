import re
from datetime import datetime, timezone
from typing import Any
from urllib.parse import urlparse

from bson import ObjectId
from bson.errors import InvalidId
from fastapi import UploadFile

from app.core.database import get_database
from app.core.exceptions import ForbiddenError, NotFoundError, ValidationError
from app.core.redis import publish
from app.models.driver import (
    DriverProfileSetup,
    DriverResponse,
    DriverUpdate,
    EarningsInfo,
)
from app.models.push_token import PushTokenRequest
from app.services.upload_service import delete_upload, save_upload
from app.utils.pagination import paginate, paginated_response

DRIVERS_COLLECTION = "drivers"
TRIPS_COLLECTION = "trips"
PUSH_TOKENS_COLLECTION = "push_tokens"
DRIVER_ROLE = "driver"
AVATARS_SUBFOLDER = "avatars"
DOCUMENTS_SUBFOLDER = "documents"

VALID_DOC_TYPES = {"drivingLicense", "vehicleRegistration", "vehiclePhoto"}
VALID_TRUCK_TYPES = {"single_cabin", "double_cabin"}


def _serialize_doc(doc: dict[str, Any]) -> dict[str, Any]:
    if doc.get("_id") is not None and not isinstance(doc["_id"], str):
        doc["_id"] = str(doc["_id"])
    if "id" not in doc and "_id" in doc:
        doc["id"] = doc["_id"]
    return doc


def _to_driver_response(doc: dict[str, Any]) -> dict[str, Any]:
    serialized = _serialize_doc(doc)
    return DriverResponse.model_validate(serialized).model_dump(by_alias=True)


def _validate_truck_type(truck_type: str) -> None:
    if truck_type not in VALID_TRUCK_TYPES:
        raise ValidationError(
            f"Invalid truck type. Allowed: {', '.join(sorted(VALID_TRUCK_TYPES))}",
        )


async def _find_driver(driver_id: str) -> dict[str, Any] | None:
    try:
        object_id = ObjectId(driver_id)
    except (InvalidId, TypeError):
        return None
    doc = await get_database()[DRIVERS_COLLECTION].find_one({"_id": object_id})
    if doc is None:
        return None
    return _serialize_doc(doc)


def _cloudinary_public_id(url: str) -> str | None:
    """Extract the Cloudinary public_id (without file extension) from a Cloudinary URL."""
    path = urlparse(url).path  # /{cloud}/image/upload/v{ver}/{public_id}.{ext}
    match = re.search(r"/upload/(?:v\d+/)?(.+?)(?:\.\w+)?$", path)
    return match.group(1) if match else None


def _avatar_key_from_url(avatar_url: str | None) -> str | None:
    if not avatar_url:
        return None
    if "cloudinary.com" in avatar_url:
        return _cloudinary_public_id(avatar_url)
    path = urlparse(avatar_url).path if "://" in avatar_url else avatar_url
    parts = path.strip("/").split("/")
    if len(parts) >= 2 and parts[-2] == AVATARS_SUBFOLDER:
        return parts[-1]
    return None


def _document_key_from_url(url: str | None) -> str | None:
    if not url:
        return None
    if "cloudinary.com" in url:
        return _cloudinary_public_id(url)
    path = urlparse(url).path if "://" in url else url
    parts = path.strip("/").split("/")
    if len(parts) >= 2 and parts[-2] == DOCUMENTS_SUBFOLDER:
        return parts[-1]
    return None


async def get_driver(driver_id: str) -> dict[str, Any]:
    driver = await _find_driver(driver_id)
    if driver is None:
        raise NotFoundError("Driver not found")
    return _to_driver_response(driver)


async def get_driver_doc(driver_id: str) -> dict[str, Any]:
    driver = await _find_driver(driver_id)
    if driver is None:
        raise NotFoundError("Driver not found")
    return driver


async def update_driver_location(driver_id: str, lat: float, lng: float) -> dict[str, Any]:
    driver = await _find_driver(driver_id)
    if driver is None:
        raise NotFoundError("Driver not found")

    now = datetime.now(timezone.utc)
    location = {"type": "Point", "coordinates": [lng, lat]}
    await get_database()[DRIVERS_COLLECTION].update_one(
        {"_id": ObjectId(driver_id)},
        {"$set": {"location": location, "updatedAt": now}},
    )
    updated = await _find_driver(driver_id)
    return updated  # type: ignore[return-value]


async def update_driver(driver_id: str, data: DriverUpdate) -> dict[str, Any]:
    driver = await _find_driver(driver_id)
    if driver is None:
        raise NotFoundError("Driver not found")

    updates: dict[str, Any] = {"updatedAt": datetime.now(timezone.utc)}
    payload = data.model_dump(exclude_unset=True)
    if "name" in payload:
        updates["name"] = payload["name"]
    if "avatarUrl" in payload:
        updates["avatarUrl"] = payload["avatarUrl"]
    if "truckType" in payload:
        _validate_truck_type(payload["truckType"])
        updates["truckType"] = payload["truckType"]
    if "vehiclePlate" in payload:
        updates["vehiclePlate"] = payload["vehiclePlate"]
    if "vehicleColor" in payload:
        updates["vehicleColor"] = payload["vehicleColor"]
    if "vehicleModel" in payload:
        updates["vehicleModel"] = payload["vehicleModel"]

    await get_database()[DRIVERS_COLLECTION].update_one(
        {"_id": ObjectId(driver_id)},
        {"$set": updates},
    )
    updated = await _find_driver(driver_id)
    return _to_driver_response(updated)  # type: ignore[arg-type]


async def complete_profile(driver_id: str, data: DriverProfileSetup) -> dict[str, Any]:
    driver = await _find_driver(driver_id)
    if driver is None:
        raise NotFoundError("Driver not found")

    _validate_truck_type(data.truckType)
    now = datetime.now(timezone.utc)
    await get_database()[DRIVERS_COLLECTION].update_one(
        {"_id": ObjectId(driver_id)},
        {
            "$set": {
                "name": data.name,
                "truckType": data.truckType,
                "vehiclePlate": data.vehiclePlate,
                "vehicleColor": data.vehicleColor,
                "vehicleModel": data.vehicleModel,
                "profileComplete": True,
                "updatedAt": now,
            },
        },
    )
    updated = await _find_driver(driver_id)
    return _to_driver_response(updated)  # type: ignore[arg-type]


async def update_avatar(driver_id: str, file: UploadFile) -> dict[str, Any]:
    driver = await _find_driver(driver_id)
    if driver is None:
        raise NotFoundError("Driver not found")

    old_key = _avatar_key_from_url(driver.get("avatarUrl"))
    if old_key:
        await delete_upload(old_key, subfolder=AVATARS_SUBFOLDER)

    upload = await save_upload(file, subfolder=AVATARS_SUBFOLDER)
    now = datetime.now(timezone.utc)
    await get_database()[DRIVERS_COLLECTION].update_one(
        {"_id": ObjectId(driver_id)},
        {"$set": {"avatarUrl": upload["url"], "updatedAt": now}},
    )
    updated = await _find_driver(driver_id)
    return _to_driver_response(updated)  # type: ignore[arg-type]


async def set_availability(driver_id: str, status: str) -> dict[str, Any]:
    driver = await _find_driver(driver_id)
    if driver is None:
        raise NotFoundError("Driver not found")

    if status == "online" and driver.get("approvalStatus") != "approved":
        raise ForbiddenError("Not approved yet")

    now = datetime.now(timezone.utc)
    await get_database()[DRIVERS_COLLECTION].update_one(
        {"_id": ObjectId(driver_id)},
        {"$set": {"availability": status, "updatedAt": now}},
    )
    await publish(
        "driver:availability_changed",
        {"driverId": driver_id, "status": status},
    )
    updated = await _find_driver(driver_id)
    return _to_driver_response(updated)  # type: ignore[arg-type]


async def get_approval_status(driver_id: str) -> dict[str, Any]:
    driver = await _find_driver(driver_id)
    if driver is None:
        raise NotFoundError("Driver not found")

    documents = driver.get("documents") or {}
    doc_summary: dict[str, dict[str, Any]] = {}
    for doc_type, entry in documents.items():
        if isinstance(entry, dict):
            doc_summary[doc_type] = {
                "status": entry.get("status", "pending"),
                "rejectionReason": entry.get("rejectionReason"),
            }
    return {
        "approvalStatus": driver.get("approvalStatus", "pending"),
        "documents": doc_summary,
    }


async def upload_document(driver_id: str, doc_type: str, file: UploadFile) -> dict[str, Any]:
    if doc_type not in VALID_DOC_TYPES:
        raise ValidationError(
            f"Invalid document type. Allowed: {', '.join(sorted(VALID_DOC_TYPES))}",
        )

    driver = await _find_driver(driver_id)
    if driver is None:
        raise NotFoundError("Driver not found")

    documents = driver.get("documents") or {}
    existing = documents.get(doc_type)
    if isinstance(existing, dict):
        old_key = _document_key_from_url(existing.get("url"))
        if old_key:
            await delete_upload(old_key, subfolder=DOCUMENTS_SUBFOLDER)

    upload = await save_upload(file, subfolder=DOCUMENTS_SUBFOLDER)
    now = datetime.now(timezone.utc)
    entry = {
        "url": upload["url"],
        "status": "pending",
        "uploadedAt": now,
        "rejectionReason": None,
    }
    await get_database()[DRIVERS_COLLECTION].update_one(
        {"_id": ObjectId(driver_id)},
        {
            "$set": {
                f"documents.{doc_type}": entry,
                "updatedAt": now,
            },
        },
    )
    await publish(
        "driver:doc_submitted",
        {"driverId": driver_id, "documentType": doc_type},
    )
    return {"documentType": doc_type, **entry}


async def get_documents(driver_id: str) -> dict[str, Any]:
    driver = await _find_driver(driver_id)
    if driver is None:
        raise NotFoundError("Driver not found")
    return {"documents": driver.get("documents") or {}}


async def get_earnings(driver_id: str) -> dict[str, Any]:
    driver = await _find_driver(driver_id)
    if driver is None:
        raise NotFoundError("Driver not found")
    earnings = driver.get("earnings") or {}
    return EarningsInfo.model_validate(earnings).model_dump()


def _serialize_trip(doc: dict[str, Any]) -> dict[str, Any]:
    return _serialize_doc(doc)


async def get_driver_trips(driver_id: str, page: int, limit: int) -> dict[str, Any]:
    params = paginate(page, limit)
    collection = get_database()[TRIPS_COLLECTION]
    query = {"driverId": driver_id}

    total = await collection.count_documents(query)
    cursor = (
        collection.find(query)
        .sort("createdAt", -1)
        .skip(params["skip"])
        .limit(params["limit"])
    )
    items = [_serialize_trip(doc) async for doc in cursor]
    return paginated_response(items, total, params["page"], params["limit"])


async def get_driver_trip(driver_id: str, trip_id: str) -> dict[str, Any]:
    try:
        trip_oid = ObjectId(trip_id)
    except (InvalidId, TypeError) as exc:
        raise NotFoundError("Trip not found") from exc

    trip = await get_database()[TRIPS_COLLECTION].find_one({"_id": trip_oid})
    if trip is None:
        raise NotFoundError("Trip not found")
    if trip.get("driverId") != driver_id:
        raise ForbiddenError("You do not have access to this trip")
    return _serialize_trip(trip)


async def upsert_push_token(driver_id: str, data: PushTokenRequest) -> dict[str, Any]:
    now = datetime.now(timezone.utc)
    collection = get_database()[PUSH_TOKENS_COLLECTION]
    await collection.update_one(
        {"ownerId": driver_id, "role": DRIVER_ROLE},
        {
            "$set": {
                "ownerId": driver_id,
                "role": DRIVER_ROLE,
                "token": data.token,
                "platform": data.platform,
                "createdAt": now,
            },
        },
        upsert=True,
    )
    doc = await collection.find_one({"ownerId": driver_id, "role": DRIVER_ROLE})
    return _serialize_doc(doc)  # type: ignore[arg-type]


async def remove_push_token(driver_id: str) -> None:
    await get_database()[PUSH_TOKENS_COLLECTION].delete_one(
        {"ownerId": driver_id, "role": DRIVER_ROLE},
    )
