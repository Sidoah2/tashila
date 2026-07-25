import logging
from typing import Optional

from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
from pymongo import ASCENDING, DESCENDING, GEOSPHERE

from app.core.config import Settings, settings as app_settings

logger = logging.getLogger(__name__)

_client: Optional[AsyncIOMotorClient] = None
_db: Optional[AsyncIOMotorDatabase] = None


class _DatabaseRef:
    """Shortcut to the active Motor database via `.db`."""

    @property
    def db(self) -> AsyncIOMotorDatabase:
        return get_database()


db = _DatabaseRef()


def get_database() -> AsyncIOMotorDatabase:
    if _db is None:
        raise RuntimeError("Database is not initialized. Call connect_db() first.")
    return _db


async def create_indexes(database: AsyncIOMotorDatabase) -> None:
    users = database["users"]
    await users.create_index([("phone", ASCENDING)], unique=True)
    await users.create_index([("createdAt", DESCENDING)])

    drivers = database["drivers"]
    await drivers.create_index([("phone", ASCENDING)], unique=True)
    await drivers.create_index([("location", GEOSPHERE)])
    await drivers.create_index([("approvalStatus", ASCENDING)])
    await drivers.create_index([("availability", ASCENDING)])
    await drivers.create_index(
        [
            ("availability", ASCENDING),
            ("approvalStatus", ASCENDING),
            ("truckType", ASCENDING),
        ],
    )
    await drivers.create_index([("createdAt", DESCENDING)])

    trips = database["trips"]
    await trips.create_index([("clientId", ASCENDING)])
    await trips.create_index([("driverId", ASCENDING)])
    await trips.create_index([("status", ASCENDING)])
    await trips.create_index([("createdAt", DESCENDING)])
    await trips.create_index(
        [
            ("status", ASCENDING),
            ("truckType", ASCENDING),
            ("createdAt", DESCENDING),
        ],
    )
    await trips.create_index([("pickupLocation", GEOSPHERE)])

    push_tokens = database["push_tokens"]
    await push_tokens.create_index(
        [("ownerId", ASCENDING), ("role", ASCENDING)],
        unique=True,
    )

    admin_users = database["admin_users"]
    await admin_users.create_index([("email", ASCENDING)], unique=True)

    pricing = database["pricing"]
    await pricing.create_index([("truckType", ASCENDING)], unique=True)

    driver_payments = database["driver_payments"]
    await driver_payments.create_index([("driverId", ASCENDING)])
    await driver_payments.create_index([("createdAt", DESCENDING)])


async def connect_db(settings: Settings | None = None) -> AsyncIOMotorDatabase:
    global _client, _db

    cfg = settings or app_settings
    _client = AsyncIOMotorClient(cfg.mongo_uri)
    _db = _client[cfg.mongo_db_name]

    await create_indexes(_db)
    logger.info("MongoDB connected")
    logger.info("Indexes created")

    return _db


async def close_db() -> None:
    global _client, _db

    if _client is not None:
        _client.close()
        logger.info("MongoDB disconnected")

    _client = None
    _db = None


async def health_check() -> bool:
    try:
        database = get_database()
        await database.command("ping")
        return True
    except Exception:
        logger.debug("MongoDB health check failed", exc_info=True)
        return False


# Backwards-compatible alias
disconnect_db = close_db
