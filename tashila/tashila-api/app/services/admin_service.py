import re
from datetime import datetime, timezone
from typing import Any

from bson import ObjectId
from bson.errors import InvalidId

from app.core.database import get_database
from app.core.exceptions import ConflictError, NotFoundError, ValidationError
from app.core.redis import add_suspended_user, publish, remove_suspended_user
from app.models.admin import (
    AdminAccountStatusUpdate,
    AdminDocumentStatusUpdate,
    AdminDriverApprovalUpdate,
    AdminDriverAvailabilityUpdate,
    AdminDriverCreate,
    AdminDriverPaymentCreate,
    AdminProfileUpdate,
    AdminUserStatusUpdate,
)
from app.services.auth_service import PHONE_PATTERN
from app.services.driver_service import VALID_DOC_TYPES, VALID_TRUCK_TYPES
from app.services.notification_service import (
    push_document_status,
    push_driver_approved,
    send_push,
)
from app.services import upload_service
from fastapi import UploadFile
from app.utils.pagination import paginate, paginated_response

USERS_COLLECTION = "users"
DRIVERS_COLLECTION = "drivers"
TRIPS_COLLECTION = "trips"
DRIVER_PAYMENTS_COLLECTION = "driver_payments"

USER_STATUSES = frozenset({"active", "suspended"})
APPROVAL_STATUSES = frozenset({"approved", "rejected"})
DOC_STATUSES = frozenset({"approved", "rejected"})
AVAILABILITY_STATUSES = frozenset({"online", "offline"})


def _serialize_doc(doc: dict[str, Any]) -> dict[str, Any]:
    if doc.get("_id") is not None and not isinstance(doc["_id"], str):
        doc["_id"] = str(doc["_id"])
    if "id" not in doc and "_id" in doc:
        doc["id"] = doc["_id"]
    return doc


def _admin_id(admin: dict[str, Any]) -> str:
    return str(admin.get("id") or admin.get("_id", ""))


def _validate_phone(phone: str) -> None:
    if not PHONE_PATTERN.match(phone):
        raise ValidationError("Phone must start with + and contain 8–15 digits")


def _build_search_filter(search: str | None, fields: list[str]) -> dict[str, Any]:
    if not search or not search.strip():
        return {}
    pattern = re.escape(search.strip())
    return {"$or": [{field: {"$regex": pattern, "$options": "i"}} for field in fields]}


async def _find_user(user_id: str) -> dict[str, Any] | None:
    try:
        oid = ObjectId(user_id)
    except (InvalidId, TypeError):
        return None
    doc = await get_database()[USERS_COLLECTION].find_one({"_id": oid})
    return _serialize_doc(doc) if doc else None


async def _find_driver(driver_id: str) -> dict[str, Any] | None:
    try:
        oid = ObjectId(driver_id)
    except (InvalidId, TypeError):
        return None
    doc = await get_database()[DRIVERS_COLLECTION].find_one({"_id": oid})
    return _serialize_doc(doc) if doc else None


async def _trip_counts_for_clients(client_ids: list[str]) -> dict[str, int]:
    if not client_ids:
        return {}
    pipeline = [
        {"$match": {"clientId": {"$in": client_ids}}},
        {"$group": {"_id": "$clientId", "count": {"$sum": 1}}},
    ]
    counts: dict[str, int] = {}
    async for row in get_database()[TRIPS_COLLECTION].aggregate(pipeline):
        counts[row["_id"]] = row["count"]
    return counts


async def _last_trips(
    field: str,
    owner_id: str,
    limit: int = 10,
) -> list[dict[str, Any]]:
    cursor = (
        get_database()[TRIPS_COLLECTION]
        .find({field: owner_id})
        .sort("createdAt", -1)
        .limit(limit)
    )
    return [_serialize_doc(doc) async for doc in cursor]


async def _driver_average_rating(driver_id: str) -> float | None:
    driver = await _find_driver(driver_id)
    if driver and driver.get("rating") is not None:
        return float(driver["rating"])

    pipeline = [
        {"$match": {"driverId": driver_id, "driverRating": {"$ne": None}}},
        {"$group": {"_id": None, "avgRating": {"$avg": "$driverRating"}}},
    ]
    rows = await get_database()[TRIPS_COLLECTION].aggregate(pipeline).to_list(1)
    if not rows:
        return None
    return round(float(rows[0]["avgRating"]), 2)


def _user_list_item(user: dict[str, Any], trip_count: int, average_rating: float = 0.0) -> dict[str, Any]:
    name = user.get("name")
    if not name:
        name = f"{user.get('firstName') or ''} {user.get('lastName') or ''}".strip()
    return {
        "id": user["id"],
        "phone": user.get("phone"),
        "name": name,
        "avatarUrl": user.get("avatarUrl"),
        "locale": user.get("locale"),
        "profileComplete": user.get("profileComplete", False),
        "status": user.get("status", "active"),
        "createdAt": user.get("createdAt"),
        "tripCount": trip_count,
        "averageRating": average_rating,
    }


async def _client_average_ratings(client_ids: list[str]) -> dict[str, float]:
    if not client_ids:
        return {}
    pipeline = [
        {"$match": {"clientId": {"$in": client_ids}, "clientRating": {"$ne": None}}},
        {"$group": {"_id": "$clientId", "avgRating": {"$avg": "$clientRating"}}},
    ]
    ratings: dict[str, float] = {}
    async for row in get_database()[TRIPS_COLLECTION].aggregate(pipeline):
        ratings[row["_id"]] = round(float(row["avgRating"]), 2)
    return ratings


async def _trip_counts_by_status_for_client(client_id: str) -> dict[str, int]:
    pipeline = [
        {"$match": {"clientId": client_id}},
        {"$group": {"_id": "$status", "count": {"$sum": 1}}},
    ]
    counts = {"completed": 0, "cancelled": 0}
    async for row in get_database()[TRIPS_COLLECTION].aggregate(pipeline):
        status = row["_id"]
        if status in counts:
            counts[status] = row["count"]
    return counts


# --- Users ---


async def admin_list_users(
    search: str | None = None,
    status: str | None = None,
    page: int = 1,
    limit: int = 20,
) -> dict[str, Any]:
    query: dict[str, Any] = {}
    if status:
        query["status"] = status
    else:
        query["status"] = {"$ne": "deleted"}
    search_filter = _build_search_filter(search, ["firstName", "lastName", "phone"])
    if search_filter:
        query = {"$and": [query, search_filter]} if query else search_filter

    params = paginate(page, limit)
    collection = get_database()[USERS_COLLECTION]
    total = await collection.count_documents(query)
    cursor = (
        collection.find(query)
        .sort("createdAt", -1)
        .skip(params["skip"])
        .limit(params["limit"])
    )
    users = [_serialize_doc(doc) async for doc in cursor]
    client_ids = [u["id"] for u in users]
    trip_counts = await _trip_counts_for_clients(client_ids)
    average_ratings = await _client_average_ratings(client_ids)
    items = [
        _user_list_item(
            u,
            trip_counts.get(u["id"], 0),
            average_ratings.get(u["id"], 0.0),
        )
        for u in users
    ]
    return paginated_response(items, total, params["page"], params["limit"])


async def admin_get_user(user_id: str) -> dict[str, Any]:
    user = await _find_user(user_id)
    if user is None:
        raise NotFoundError("User not found")
    trips = await _last_trips("clientId", user_id)
    reviews = await _client_reviews_for_user(user_id)
    avg_rating = await _client_average_rating(user_id)
    status_counts = await _trip_counts_by_status_for_client(user_id)
    name = user.get("name")
    if not name:
        name = f"{user.get('firstName') or ''} {user.get('lastName') or ''}".strip()
    total_trips = await get_database()[TRIPS_COLLECTION].count_documents({"clientId": user_id})
    return {
        **user,
        "name": name,
        "trips": trips,
        "reviews": reviews,
        "averageRating": avg_rating,
        "completedTripsCount": status_counts["completed"],
        "cancelledTripsCount": status_counts["cancelled"],
        "tripCount": total_trips,
        "totalTrips": total_trips,
    }


async def _client_reviews_for_user(user_id: str, limit: int = 20) -> list[dict[str, Any]]:
    cursor = (
        get_database()[TRIPS_COLLECTION]
        .find({"clientId": user_id, "driverRating": {"$ne": None}})
        .sort("completedAt", -1)
        .limit(limit)
    )
    reviews: list[dict[str, Any]] = []
    async for trip in cursor:
        driver = await _find_driver(trip.get("driverId", ""))
        reviews.append({
            "tripId": str(trip["_id"]),
            "rating": trip.get("driverRating"),
            "comment": trip.get("driverRatingComment"),
            "driverName": (driver or {}).get("name"),
            "createdAt": trip.get("completedAt") or trip.get("updatedAt"),
        })
    return reviews


async def _client_average_rating(user_id: str) -> float | None:
    pipeline = [
        {"$match": {"clientId": user_id, "driverRating": {"$ne": None}}},
        {"$group": {"_id": None, "avgRating": {"$avg": "$driverRating"}}},
    ]
    rows = await get_database()[TRIPS_COLLECTION].aggregate(pipeline).to_list(1)
    if not rows:
        return None
    return round(float(rows[0]["avgRating"]), 2)


async def admin_get_user_reviews(user_id: str) -> list[dict[str, Any]]:
    user = await _find_user(user_id)
    if user is None:
        raise NotFoundError("User not found")
    return await _client_reviews_for_user(user_id)


async def _driver_customer_reviews(driver_id: str, limit: int = 20) -> list[dict[str, Any]]:
    cursor = (
        get_database()[TRIPS_COLLECTION]
        .find({"driverId": driver_id, "driverRating": {"$ne": None}})
        .sort("completedAt", -1)
        .limit(limit)
    )
    reviews: list[dict[str, Any]] = []
    async for trip in cursor:
        client = await _find_user(trip.get("clientId", ""))
        reviews.append({
            "tripId": str(trip["_id"]),
            "rating": trip.get("driverRating"),
            "comment": trip.get("driverRatingComment"),
            "clientName": (client or {}).get("name") or trip.get("externalLabel"),
            "createdAt": trip.get("completedAt") or trip.get("updatedAt"),
        })
    return reviews


async def _driver_platform_payments(driver_id: str) -> list[dict[str, Any]]:
    cursor = (
        get_database()[DRIVER_PAYMENTS_COLLECTION]
        .find({"driverId": driver_id})
        .sort("createdAt", -1)
        .limit(50)
    )
    payments: list[dict[str, Any]] = []
    async for doc in cursor:
        payments.append(_serialize_doc(doc))
    return payments


async def admin_get_driver_reviews(driver_id: str) -> list[dict[str, Any]]:
    driver = await _find_driver(driver_id)
    if driver is None:
        raise NotFoundError("Driver not found")
    return await _driver_customer_reviews(driver_id)


async def admin_update_user_status(user_id: str, body: AdminUserStatusUpdate) -> dict[str, Any]:
    if body.status not in USER_STATUSES:
        raise ValidationError("status must be 'active' or 'suspended'")

    user = await _find_user(user_id)
    if user is None:
        raise NotFoundError("User not found")
    if user.get("status") == "deleted":
        raise ValidationError("Cannot reactivate a deleted account")

    now = datetime.now(timezone.utc)
    await get_database()[USERS_COLLECTION].update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"status": body.status, "updatedAt": now}},
    )

    if body.status == "suspended":
        await add_suspended_user(user_id)
        await send_push(
            user_id,
            "client",
            "Account suspended",
            "Your account has been suspended by the admin.",
            {"type": "account_suspended"},
        )
    else:
        await remove_suspended_user(user_id)

    updated = await _find_user(user_id)
    return updated  # type: ignore[return-value]


async def admin_update_driver_status(driver_id: str, body: AdminUserStatusUpdate) -> dict[str, Any]:
    if body.status not in USER_STATUSES:
        raise ValidationError("status must be 'active' or 'suspended'")

    driver = await _find_driver(driver_id)
    if driver is None:
        raise NotFoundError("Driver not found")
    if driver.get("status") == "deleted":
        raise ValidationError("Cannot reactivate a deleted account")

    now = datetime.now(timezone.utc)
    await get_database()[DRIVERS_COLLECTION].update_one(
        {"_id": ObjectId(driver_id)},
        {"$set": {"status": body.status, "updatedAt": now}},
    )

    if body.status == "suspended":
        await add_suspended_user(driver_id)
        await send_push(
            driver_id,
            "driver",
            "Account suspended",
            "Your account has been suspended by the admin.",
            {"type": "account_suspended"},
        )
    else:
        await remove_suspended_user(driver_id)

    updated = await _find_driver(driver_id)
    return updated  # type: ignore[return-value]


# --- Drivers ---


async def admin_list_drivers(
    approval: str | None = None,
    availability: str | None = None,
    truck_type: str | None = None,
    search: str | None = None,
    page: int = 1,
    limit: int = 20,
) -> dict[str, Any]:
    query: dict[str, Any] = {"status": {"$ne": "deleted"}}
    if approval:
        query["approvalStatus"] = approval
    if availability:
        query["availability"] = availability
    if truck_type:
        query["truckType"] = truck_type
    search_filter = _build_search_filter(search, ["name", "phone", "vehiclePlate"])
    if search_filter:
        query = {"$and": [query, search_filter]} if query else search_filter

    params = paginate(page, limit)
    collection = get_database()[DRIVERS_COLLECTION]
    total = await collection.count_documents(query)
    cursor = (
        collection.find(query)
        .sort("createdAt", -1)
        .skip(params["skip"])
        .limit(params["limit"])
    )
    items = [_serialize_doc(doc) async for doc in cursor]
    enriched: list[dict[str, Any]] = []
    for item in items:
        driver_id = item["id"]
        reviews = await _driver_customer_reviews(driver_id, limit=1)
        completed_trips = await _driver_completed_trips_count(driver_id)
        enriched.append({**item, "customerReviews": reviews, "completedTrips": completed_trips})
    return paginated_response(enriched, total, params["page"], params["limit"])


async def admin_list_pending_drivers() -> list[dict[str, Any]]:
    cursor = (
        get_database()[DRIVERS_COLLECTION]
        .find({"approvalStatus": "pending"})
        .sort("createdAt", 1)
    )
    return [_serialize_doc(doc) async for doc in cursor]


async def _driver_completed_trips_count(driver_id: str) -> int:
    return await get_database()[TRIPS_COLLECTION].count_documents(
        {"driverId": driver_id, "status": "completed"}
    )


async def admin_upload_driver_avatar(driver_id: str, file: UploadFile) -> dict[str, Any]:
    driver = await _find_driver(driver_id)
    if driver is None:
        raise NotFoundError("Driver not found")
    from app.services import driver_service
    await driver_service.update_avatar(driver_id, file)
    return await admin_get_driver(driver_id)


async def admin_get_driver(driver_id: str) -> dict[str, Any]:
    driver = await _find_driver(driver_id)
    if driver is None:
        raise NotFoundError("Driver not found")

    trips = await _last_trips("driverId", driver_id, limit=1000)
    avg_rating = await _driver_average_rating(driver_id)
    customer_reviews = await _driver_customer_reviews(driver_id)
    platform_payments = await _driver_platform_payments(driver_id)
    completed_trips = await _driver_completed_trips_count(driver_id)
    return {
        **driver,
        "documents": driver.get("documents") or {},
        "earnings": driver.get("earnings") or {
            "totalEarnedDzd": 0.0,
            "platformDueDzd": 0.0,
            "paidDzd": 0.0,
            "creditDzd": 0.0,
        },
        "trips": trips,
        "averageRating": avg_rating,
        "customerReviews": customer_reviews,
        "platformPayments": platform_payments,
        "completedTrips": completed_trips,
    }


async def admin_create_driver(body: AdminDriverCreate) -> dict[str, Any]:
    _validate_phone(body.phone)
    if body.truckType not in VALID_TRUCK_TYPES:
        raise ValidationError(
            f"Invalid truck type. Allowed: {', '.join(sorted(VALID_TRUCK_TYPES))}",
        )

    collection = get_database()[DRIVERS_COLLECTION]
    existing = await collection.find_one({"phone": body.phone})
    if existing is not None:
        raise ConflictError("Driver with this phone already exists")

    now = datetime.now(timezone.utc)
    doc = {
        "phone": body.phone,
        "name": body.name,
        "truckType": body.truckType,
        "vehiclePlate": body.vehiclePlate,
        "vehicleColor": body.vehicleColor,
        "vehicleModel": body.vehicleModel,
        "availability": "offline",
        "approvalStatus": "pending",
        "documents": {},
        "earnings": {
            "totalEarnedDzd": 0.0,
            "platformDueDzd": 0.0,
            "paidDzd": 0.0,
            "creditDzd": 0.0,
        },
        "profileComplete": True,
        "status": "active",
        "createdAt": now,
        "updatedAt": now,
    }
    result = await collection.insert_one(doc)
    doc["_id"] = str(result.inserted_id)
    return _serialize_doc(doc)


async def admin_update_driver_approval(
    driver_id: str,
    body: AdminDriverApprovalUpdate,
) -> dict[str, Any]:
    if body.status not in APPROVAL_STATUSES:
        raise ValidationError("status must be 'approved' or 'rejected'")
    if body.status == "rejected" and not body.reason:
        raise ValidationError("reason is required when rejecting")

    driver = await _find_driver(driver_id)
    if driver is None:
        raise NotFoundError("Driver not found")

    if body.status == "approved":
        documents = driver.get("documents") or {}
        required_docs = {"drivingLicense", "vehicleRegistration", "vehiclePhoto"}
        missing_docs = required_docs - set(documents.keys())
        if missing_docs:
            raise ValidationError(
                f"Cannot approve driver. Missing documents: {', '.join(sorted(missing_docs))}"
            )
        unapproved_docs = []
        for doc_type in required_docs:
            doc_entry = documents.get(doc_type)
            if not isinstance(doc_entry, dict) or doc_entry.get("status") != "approved":
                unapproved_docs.append(doc_type)
        if unapproved_docs:
            raise ValidationError(
                f"Cannot approve driver. The following documents are not approved yet: {', '.join(sorted(unapproved_docs))}"
            )

    now = datetime.now(timezone.utc)
    updates: dict[str, Any] = {
        "approvalStatus": body.status,
        "updatedAt": now,
    }
    if body.status == "rejected":
        updates["rejectionReason"] = body.reason
        updates["availability"] = "offline"
    else:
        updates["rejectionReason"] = None

    await get_database()[DRIVERS_COLLECTION].update_one(
        {"_id": ObjectId(driver_id)},
        {"$set": updates},
    )

    if body.status == "approved":
        await push_driver_approved(driver_id)
    else:
        await send_push(
            driver_id,
            "driver",
            "Account rejected",
            body.reason or "Your application was rejected.",
            {"type": "driver_rejected", "status": "rejected"},
        )

    return await admin_get_driver(driver_id)


async def admin_update_document_status(
    driver_id: str,
    doc_type: str,
    body: AdminDocumentStatusUpdate,
) -> dict[str, Any]:
    if doc_type not in VALID_DOC_TYPES:
        raise ValidationError(
            f"Invalid document type. Allowed: {', '.join(sorted(VALID_DOC_TYPES))}",
        )
    if body.status not in DOC_STATUSES:
        raise ValidationError("status must be 'approved' or 'rejected'")
    if body.status == "rejected" and not body.rejectionReason:
        raise ValidationError("rejectionReason is required when rejecting")

    driver = await _find_driver(driver_id)
    if driver is None:
        raise NotFoundError("Driver not found")

    documents = driver.get("documents") or {}
    entry = documents.get(doc_type)
    if not isinstance(entry, dict):
        raise NotFoundError(f"Document '{doc_type}' not found for this driver")

    now = datetime.now(timezone.utc)
    doc_updates: dict[str, Any] = {
        f"documents.{doc_type}.status": body.status,
        f"documents.{doc_type}.rejectionReason": body.rejectionReason if body.status == "rejected" else None,
        "updatedAt": now,
    }
    await get_database()[DRIVERS_COLLECTION].update_one(
        {"_id": ObjectId(driver_id)},
        {"$set": doc_updates},
    )

    await push_document_status(
        driver_id,
        doc_type,
        body.status == "approved",
        body.rejectionReason,
    )

    return await admin_get_driver(driver_id)


async def admin_upload_driver_document(
    driver_id: str,
    doc_type: str,
    file: UploadFile,
) -> dict[str, Any]:
    if doc_type not in VALID_DOC_TYPES:
        raise ValidationError(
            f"Invalid document type. Allowed: {', '.join(sorted(VALID_DOC_TYPES))}",
        )

    driver = await _find_driver(driver_id)
    if driver is None:
        raise NotFoundError("Driver not found")

    saved = await upload_service.save_upload(file, subfolder=f"drivers/{driver_id}")
    now = datetime.now(timezone.utc)
    doc_entry = {
        "type": doc_type,
        "url": saved["url"],
        "key": saved["key"],
        "status": "pending",
        "rejectionReason": None,
        "uploadedAt": now,
    }
    await get_database()[DRIVERS_COLLECTION].update_one(
        {"_id": ObjectId(driver_id)},
        {
            "$set": {
                f"documents.{doc_type}": doc_entry,
                "updatedAt": now,
            },
        },
    )
    return await admin_get_driver(driver_id)


async def admin_force_driver_availability(
    driver_id: str,
    body: AdminDriverAvailabilityUpdate,
) -> dict[str, Any]:
    if body.availability not in AVAILABILITY_STATUSES:
        raise ValidationError("availability must be 'online' or 'offline'")

    driver = await _find_driver(driver_id)
    if driver is None:
        raise NotFoundError("Driver not found")

    now = datetime.now(timezone.utc)
    await get_database()[DRIVERS_COLLECTION].update_one(
        {"_id": ObjectId(driver_id)},
        {"$set": {"availability": body.availability, "updatedAt": now}},
    )
    await publish(
        "driver:availability_changed",
        {"driverId": driver_id, "status": body.availability},
    )
    updated = await _find_driver(driver_id)
    return updated  # type: ignore[return-value]


async def admin_record_driver_payment(
    driver_id: str,
    admin: dict[str, Any],
    body: AdminDriverPaymentCreate,
) -> dict[str, Any]:
    if body.amountDzd <= 0:
        raise ValidationError("amountDzd must be greater than 0")

    driver = await _find_driver(driver_id)
    if driver is None:
        raise NotFoundError("Driver not found")

    earnings = driver.get("earnings") or {}
    platform_due = float(earnings.get("platformDueDzd", 0))
    paid = float(earnings.get("paidDzd", 0))
    credit = float(earnings.get("creditDzd", 0))

    # Net balance: existing credit minus platform dues plus newly received payment
    net_balance = (credit - platform_due) + body.amountDzd
    if net_balance >= 0:
        new_due = 0.0
        new_credit = round(net_balance, 2)
    else:
        new_due = round(abs(net_balance), 2)
        new_credit = 0.0

    new_paid = round(paid + body.amountDzd, 2)

    now = datetime.now(timezone.utc)
    await get_database()[DRIVERS_COLLECTION].update_one(
        {"_id": ObjectId(driver_id)},
        {
            "$set": {
                "earnings.platformDueDzd": new_due,
                "earnings.creditDzd": new_credit,
                "earnings.paidDzd": new_paid,
                "updatedAt": now,
            },
        },
    )

    payment_doc = {
        "driverId": driver_id,
        "amountDzd": body.amountDzd,
        "note": body.note,
        "recordedBy": _admin_id(admin),
        "createdAt": now,
    }
    result = await get_database()[DRIVER_PAYMENTS_COLLECTION].insert_one(payment_doc)
    payment_doc["id"] = str(result.inserted_id)
    payment_doc["_id"] = payment_doc["id"]

    updated = await _find_driver(driver_id)
    return {
        "payment": _serialize_doc(payment_doc),
        "driver": updated,
    }


ADMIN_USERS_COLLECTION = "admin_users"


def _serialize_admin(doc: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": str(doc["_id"]),
        "email": doc.get("email", ""),
        "name": doc.get("name", ""),
        "role": doc.get("role", "admin"),
        "status": doc.get("status", "active"),
        "createdAt": doc.get("createdAt"),
    }


async def admin_list_admins() -> list[dict[str, Any]]:
    cursor = get_database()[ADMIN_USERS_COLLECTION].find({}, {"passwordHash": 0})
    return [_serialize_admin(doc) async for doc in cursor]


async def admin_create_admin(body: dict[str, Any]) -> dict[str, Any]:
    from app.core.security import hash_password

    email = body.get("email", "").strip().lower()
    password = body.get("password", "")
    name = body.get("name", "").strip()
    role = body.get("role", "admin")

    if not email or not password or not name:
        raise ValidationError("email, password and name are required")
    if role not in ("admin", "super_admin"):
        raise ValidationError("role must be 'admin' or 'super_admin'")

    existing = await get_database()[ADMIN_USERS_COLLECTION].find_one({"email": email})
    if existing:
        raise ConflictError("An admin with this email already exists")

    now = datetime.now(timezone.utc)
    doc = {
        "email": email,
        "passwordHash": hash_password(password),
        "name": name,
        "role": role,
        "status": "active",
        "createdAt": now,
        "updatedAt": now,
    }
    result = await get_database()[ADMIN_USERS_COLLECTION].insert_one(doc)
    doc["_id"] = result.inserted_id
    return _serialize_admin(doc)


async def admin_update_admin_status(admin_id: str, body: AdminAccountStatusUpdate) -> dict[str, Any]:
    if body.status not in ("active", "suspended"):
        raise ValidationError("status must be 'active' or 'suspended'")
    try:
        oid = ObjectId(admin_id)
    except InvalidId:
        raise NotFoundError("Admin not found")

    result = await get_database()[ADMIN_USERS_COLLECTION].find_one_and_update(
        {"_id": oid},
        {"$set": {"status": body.status, "updatedAt": datetime.now(timezone.utc)}},
        return_document=True,
    )
    if result is None:
        raise NotFoundError("Admin not found")

    if body.status == "suspended":
        from app.core.redis import add_suspended_user
        await add_suspended_user(admin_id)
    else:
        from app.core.redis import remove_suspended_user
        await remove_suspended_user(admin_id)

    return _serialize_admin(result)


async def admin_update_my_profile(
    admin: dict[str, Any],
    body: AdminProfileUpdate,
) -> dict[str, Any]:
    from app.core.security import hash_password

    updates: dict[str, Any] = {"updatedAt": datetime.now(timezone.utc)}

    if body.name is not None:
        name = body.name.strip()
        if not name:
            raise ValidationError("name cannot be empty")
        updates["name"] = name

    if body.email is not None:
        email = body.email.strip().lower()
        if not email:
            raise ValidationError("email cannot be empty")
        existing = await get_database()[ADMIN_USERS_COLLECTION].find_one({"email": email})
        admin_id_str = str(admin.get("_id") or admin.get("id", ""))
        if existing and str(existing["_id"]) != admin_id_str:
            raise ConflictError("Email is already in use")
        updates["email"] = email

    if body.password is not None:
        if len(body.password) < 6:
            raise ValidationError("password must be at least 6 characters")
        updates["passwordHash"] = hash_password(body.password)

    try:
        oid = ObjectId(str(admin.get("_id") or admin.get("id", "")))
    except InvalidId:
        raise NotFoundError("Admin not found")

    result = await get_database()[ADMIN_USERS_COLLECTION].find_one_and_update(
        {"_id": oid},
        {"$set": updates},
        return_document=True,
    )
    if result is None:
        raise NotFoundError("Admin not found")
    return _serialize_admin(result)
