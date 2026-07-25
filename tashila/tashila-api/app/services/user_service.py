from datetime import datetime, timezone
from typing import Any
from urllib.parse import urlparse

from bson import ObjectId
from bson.errors import InvalidId
from fastapi import UploadFile

from app.core.database import get_database
from app.core.exceptions import ForbiddenError, NotFoundError, ConflictError
from app.models.push_token import PushTokenRequest
from app.models.user import UserProfileSetup, UserResponse, UserUpdate
from app.services.upload_service import delete_upload, save_upload
from app.utils.pagination import paginate, paginated_response

USERS_COLLECTION = "users"
TRIPS_COLLECTION = "trips"
PUSH_TOKENS_COLLECTION = "push_tokens"
CLIENT_ROLE = "client"
AVATARS_SUBFOLDER = "avatars"


def _serialize_doc(doc: dict[str, Any]) -> dict[str, Any]:
    if doc.get("_id") is not None and not isinstance(doc["_id"], str):
        doc["_id"] = str(doc["_id"])
    if "id" not in doc and "_id" in doc:
        doc["id"] = doc["_id"]
    return doc


def _to_user_response(doc: dict[str, Any]) -> dict[str, Any]:
    serialized = _serialize_doc(doc)
    return UserResponse.model_validate(serialized).model_dump(by_alias=True)


async def _find_user(user_id: str) -> dict[str, Any] | None:
    try:
        object_id = ObjectId(user_id)
    except (InvalidId, TypeError):
        return None
    doc = await get_database()[USERS_COLLECTION].find_one({"_id": object_id})
    if doc is None:
        return None
    return _serialize_doc(doc)


def _cloudinary_public_id(url: str) -> str | None:
    """Extract the Cloudinary public_id (without file extension) from a Cloudinary URL."""
    import re

    path = urlparse(url).path
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


async def get_user(user_id: str) -> dict[str, Any]:
    user = await _find_user(user_id)
    if user is None:
        raise NotFoundError("User not found")
    return _to_user_response(user)


async def update_user(user_id: str, data: UserUpdate) -> dict[str, Any]:
    user = await _find_user(user_id)
    if user is None:
        raise NotFoundError("User not found")

    updates: dict[str, Any] = {"updatedAt": datetime.now(timezone.utc)}
    payload = data.model_dump(exclude_unset=True)
    if "name" in payload:
        updates["name"] = payload["name"]
    if "locale" in payload:
        updates["locale"] = payload["locale"]
    if "avatarUrl" in payload:
        updates["avatarUrl"] = payload["avatarUrl"]

    await get_database()[USERS_COLLECTION].update_one(
        {"_id": ObjectId(user_id)},
        {"$set": updates},
    )
    updated = await _find_user(user_id)
    return _to_user_response(updated)  # type: ignore[arg-type]


async def complete_profile(user_id: str, data: UserProfileSetup) -> dict[str, Any]:
    user = await _find_user(user_id)
    if user is None:
        raise NotFoundError("User not found")

    now = datetime.now(timezone.utc)
    updates: dict[str, Any] = {
        "name": data.name,
        "profileComplete": True,
        "updatedAt": now,
    }
    if data.locale is not None:
        updates["locale"] = data.locale

    await get_database()[USERS_COLLECTION].update_one(
        {"_id": ObjectId(user_id)},
        {"$set": updates},
    )
    updated = await _find_user(user_id)
    return _to_user_response(updated)  # type: ignore[arg-type]


async def update_avatar(user_id: str, file: UploadFile) -> dict[str, Any]:
    user = await _find_user(user_id)
    if user is None:
        raise NotFoundError("User not found")

    old_key = _avatar_key_from_url(user.get("avatarUrl"))
    if old_key:
        await delete_upload(old_key, subfolder=AVATARS_SUBFOLDER)

    upload = await save_upload(file, subfolder=AVATARS_SUBFOLDER)
    now = datetime.now(timezone.utc)
    await get_database()[USERS_COLLECTION].update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"avatarUrl": upload["url"], "updatedAt": now}},
    )
    updated = await _find_user(user_id)
    return _to_user_response(updated)  # type: ignore[arg-type]


def _serialize_trip(doc: dict[str, Any]) -> dict[str, Any]:
    return _serialize_doc(doc)


async def get_user_trips(user_id: str, page: int, limit: int) -> dict[str, Any]:
    params = paginate(page, limit)
    collection = get_database()[TRIPS_COLLECTION]
    query = {"clientId": user_id}

    total = await collection.count_documents(query)
    cursor = (
        collection.find(query)
        .sort("createdAt", -1)
        .skip(params["skip"])
        .limit(params["limit"])
    )
    items = [_serialize_trip(doc) async for doc in cursor]
    return paginated_response(items, total, params["page"], params["limit"])


async def get_user_trip(user_id: str, trip_id: str) -> dict[str, Any]:
    try:
        trip_oid = ObjectId(trip_id)
    except (InvalidId, TypeError) as exc:
        raise NotFoundError("Trip not found") from exc

    trip = await get_database()[TRIPS_COLLECTION].find_one({"_id": trip_oid})
    if trip is None:
        raise NotFoundError("Trip not found")
    if trip.get("clientId") != user_id:
        raise ForbiddenError("You do not have access to this trip")
    return _serialize_trip(trip)


async def upsert_push_token(user_id: str, data: PushTokenRequest) -> dict[str, Any]:
    now = datetime.now(timezone.utc)
    collection = get_database()[PUSH_TOKENS_COLLECTION]
    await collection.update_one(
        {"ownerId": user_id, "role": CLIENT_ROLE},
        {
            "$set": {
                "ownerId": user_id,
                "role": CLIENT_ROLE,
                "token": data.token,
                "platform": data.platform,
                "createdAt": now,
            },
        },
        upsert=True,
    )
    doc = await collection.find_one({"ownerId": user_id, "role": CLIENT_ROLE})
    return _serialize_doc(doc)  # type: ignore[arg-type]


async def remove_push_token(user_id: str) -> None:
    await get_database()[PUSH_TOKENS_COLLECTION].delete_one(
        {"ownerId": user_id, "role": CLIENT_ROLE},
    )


async def delete_user(user_id: str) -> None:
    user = await _find_user(user_id)
    if user is None:
        raise NotFoundError("User not found")

    active = await get_database()[TRIPS_COLLECTION].find_one(
        {
            "clientId": user_id,
            "status": {
                "$in": [
                    "requested",
                    "accepted",
                    "headingToPickup",
                    "inProgress",
                    "awaitingCash",
                ],
            },
        },
    )
    if active is not None:
        raise ConflictError("Cannot delete account with an active trip")

    await remove_push_token(user_id)
    await get_database()[USERS_COLLECTION].update_one(
        {"_id": ObjectId(user_id)},
        {
            "$set": {
                "status": "deleted",
                "updatedAt": datetime.now(timezone.utc),
                "phone": f"deleted_{user_id}",
            },
        },
    )
