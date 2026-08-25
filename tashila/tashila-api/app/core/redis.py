import json
import logging
import secrets
from typing import Any, Optional

from redis.asyncio import Redis
from redis.asyncio.client import PubSub

from app.core.config import Settings, settings as app_settings

logger = logging.getLogger(__name__)

_redis: Optional[Redis] = None

DRIVERS_ONLINE_KEY = "drivers:online"
SUSPENDED_USERS_KEY = "suspended:users"


def _otp_key(phone: str, role: str) -> str:
    return f"otp:{role}:{phone}"


def _otp_rate_key(phone: str) -> str:
    return f"rate:otp:{phone}"


def _blacklist_key(token: str) -> str:
    return f"blacklist:{token}"


def get_redis() -> Redis:
    if _redis is None:
        raise RuntimeError("Redis is not initialized. Call connect_redis() first.")
    return _redis


async def connect_redis(settings: Settings | None = None) -> Redis:
    global _redis

    cfg = settings or app_settings
    try:
        _redis = Redis.from_url(
            cfg.redis_url,
            encoding="utf-8",
            decode_responses=True,
        )
        await _redis.ping()
        logger.info("Redis connected")
    except Exception as err:
        logger.warning(f"Could not connect to Redis server ({err}). Using in-memory FakeRedis fallback.")
        import fakeredis.aioredis
        _redis = fakeredis.aioredis.FakeRedis(decode_responses=True)
    return _redis


async def close_redis() -> None:
    global _redis

    if _redis is not None:
        await _redis.aclose()
        logger.info("Redis disconnected")
    _redis = None


async def redis_health_check() -> bool:
    try:
        redis = get_redis()
        await redis.ping()
        return True
    except Exception:
        logger.debug("Redis health check failed", exc_info=True)
        return False


# --- OTP helpers ---


async def store_otp(phone: str, role: str, otp: str, ttl: int = 120) -> None:
    redis = get_redis()
    await redis.set(_otp_key(phone, role), otp, ex=ttl)


async def verify_otp(phone: str, role: str, otp: str) -> bool:
    redis = get_redis()
    key = _otp_key(phone, role)
    stored = await redis.get(key)
    if stored is None:
        return False
    if secrets.compare_digest(stored, otp):
        await redis.delete(key)
        return True
    return False


async def otp_rate_limit(phone: str) -> bool:
    """
    Track OTP send attempts for a phone number.

    Returns True if the request is allowed, False if rate-limited.
    """
    redis = get_redis()
    key = _otp_rate_key(phone)
    count = await redis.incr(key)
    if count == 1:
        await redis.expire(key, app_settings.otp_window_seconds)
    if count > app_settings.max_otp_attempts:
        return False
    return True


# --- Token blacklist ---


async def blacklist_token(token: str, ttl_seconds: int) -> None:
    redis = get_redis()
    await redis.set(_blacklist_key(token), "1", ex=ttl_seconds)


async def is_token_blacklisted(token: str) -> bool:
    redis = get_redis()
    return bool(await redis.exists(_blacklist_key(token)))


# --- Driver socket mapping ---


async def set_driver_socket(driver_id: str, sid: str) -> None:
    redis = get_redis()
    await redis.hset(DRIVERS_ONLINE_KEY, driver_id, sid)


async def remove_driver_socket(driver_id: str) -> None:
    redis = get_redis()
    await redis.hdel(DRIVERS_ONLINE_KEY, driver_id)


async def get_driver_socket(driver_id: str) -> str | None:
    redis = get_redis()
    return await redis.hget(DRIVERS_ONLINE_KEY, driver_id)


async def get_all_online_drivers() -> dict[str, str]:
    redis = get_redis()
    result = await redis.hgetall(DRIVERS_ONLINE_KEY)
    return dict(result)


# --- Pub/sub ---


async def publish(channel: str, message: dict[str, Any]) -> int:
    redis = get_redis()
    return await redis.publish(channel, json.dumps(message))


def get_pubsub() -> PubSub:
    return get_redis().pubsub()


def _rejected_key(driver_id: str) -> str:
    return f"rejected:{driver_id}"


async def add_rejected_trip(driver_id: str, trip_id: str, ttl_seconds: int = 3600) -> None:
    redis = get_redis()
    key = _rejected_key(driver_id)
    await redis.sadd(key, trip_id)
    await redis.expire(key, ttl_seconds)


async def get_rejected_trip_ids(driver_id: str) -> set[str]:
    redis = get_redis()
    members = await redis.smembers(_rejected_key(driver_id))
    return set(members)


async def is_trip_rejected_by_driver(driver_id: str, trip_id: str) -> bool:
    redis = get_redis()
    return bool(await redis.sismember(_rejected_key(driver_id), trip_id))


async def add_suspended_user(user_id: str) -> None:
    redis = get_redis()
    await redis.sadd(SUSPENDED_USERS_KEY, user_id)


async def remove_suspended_user(user_id: str) -> None:
    redis = get_redis()
    await redis.srem(SUSPENDED_USERS_KEY, user_id)


async def is_user_suspended(user_id: str) -> bool:
    redis = get_redis()
    return bool(await redis.sismember(SUSPENDED_USERS_KEY, user_id))


# --- Trip dispatch offers ---


def _trip_offer_key(trip_id: str) -> str:
    return f"offer:{trip_id}"


def _dispatch_lock_key(trip_id: str) -> str:
    return f"dispatch:lock:{trip_id}"


def _driver_busy_key(driver_id: str) -> str:
    return f"driver:busy:{driver_id}"


def _driver_offer_key(driver_id: str) -> str:
    return f"driver:offer:{driver_id}"


async def set_trip_offer(
    trip_id: str,
    *,
    driver_id: str,
    expires_at: str,
    generation: int,
    candidate_index: int,
    ttl_seconds: int,
) -> None:
    redis = get_redis()
    payload = {
        "driverId": driver_id,
        "expiresAt": expires_at,
        "generation": generation,
        "candidateIndex": candidate_index,
    }
    pipe = redis.pipeline()
    pipe.set(_trip_offer_key(trip_id), json.dumps(payload), ex=ttl_seconds)
    pipe.set(_driver_offer_key(driver_id), trip_id, ex=ttl_seconds)
    await pipe.execute()


async def set_trip_broadcast_offers(
    trip_id: str,
    *,
    driver_ids: list[str],
    expires_at: str,
    generation: int,
    ttl_seconds: int,
) -> None:
    redis = get_redis()
    payload = {
        "driverIds": driver_ids,
        "expiresAt": expires_at,
        "generation": generation,
    }
    pipe = redis.pipeline()
    pipe.set(_trip_offer_key(trip_id), json.dumps(payload), ex=ttl_seconds)
    for driver_id in driver_ids:
        pipe.set(_driver_offer_key(driver_id), trip_id, ex=ttl_seconds)
    await pipe.execute()


async def get_trip_offer(trip_id: str) -> dict[str, Any] | None:
    redis = get_redis()
    raw = await redis.get(_trip_offer_key(trip_id))
    if not raw:
        return None
    return json.loads(raw)


async def get_driver_offer_trip_id(driver_id: str) -> str | None:
    redis = get_redis()
    return await redis.get(_driver_offer_key(driver_id))


async def remove_driver_from_offer(trip_id: str, driver_id: str) -> bool:
    """
    Removes a driver from the active offer's driverIds.
    Returns True if no drivers remain in the offer.
    """
    redis = get_redis()
    offer = await get_trip_offer(trip_id)
    if not offer:
        return True

    # Delete driver-specific offer mapping if it still points to this trip
    current_trip = await redis.get(_driver_offer_key(driver_id))
    if current_trip == trip_id:
        await redis.delete(_driver_offer_key(driver_id))

    driver_ids = offer.get("driverIds", [])
    if not driver_ids and offer.get("driverId"):
        driver_ids = [offer["driverId"]]

    if driver_id in driver_ids:
        driver_ids.remove(driver_id)

    if not driver_ids:
        await redis.delete(_trip_offer_key(trip_id))
        return True

    offer["driverIds"] = driver_ids
    ttl = await redis.ttl(_trip_offer_key(trip_id))
    if ttl > 0:
        await redis.set(_trip_offer_key(trip_id), json.dumps(offer), ex=ttl)
        return False
    else:
        await redis.delete(_trip_offer_key(trip_id))
        return True


async def clear_trip_offer(trip_id: str) -> None:
    redis = get_redis()
    offer = await get_trip_offer(trip_id)
    driver_ids = []
    if offer:
        driver_ids = offer.get("driverIds", [])
        if not driver_ids and offer.get("driverId"):
            driver_ids = [offer["driverId"]]

    pipe = redis.pipeline()
    pipe.delete(_trip_offer_key(trip_id))
    for driver_id in driver_ids:
        current_trip_id = await redis.get(_driver_offer_key(driver_id))
        if current_trip_id == trip_id:
            pipe.delete(_driver_offer_key(driver_id))
    await pipe.execute()


async def acquire_dispatch_lock(trip_id: str, token: str, ttl_seconds: int) -> bool:
    redis = get_redis()
    return bool(
        await redis.set(_dispatch_lock_key(trip_id), token, nx=True, ex=ttl_seconds),
    )


async def release_dispatch_lock(trip_id: str, token: str) -> None:
    redis = get_redis()
    key = _dispatch_lock_key(trip_id)
    current = await redis.get(key)
    if current == token:
        await redis.delete(key)


async def set_driver_busy(driver_id: str, trip_id: str, ttl_seconds: int = 86_400) -> None:
    redis = get_redis()
    await redis.set(_driver_busy_key(driver_id), trip_id, ex=ttl_seconds)


async def clear_driver_busy(driver_id: str) -> None:
    redis = get_redis()
    await redis.delete(_driver_busy_key(driver_id))


async def is_driver_busy(driver_id: str) -> bool:
    redis = get_redis()
    return bool(await redis.exists(_driver_busy_key(driver_id)))


async def get_driver_busy_trip_id(driver_id: str) -> str | None:
    redis = get_redis()
    return await redis.get(_driver_busy_key(driver_id))


def _dispatch_wake_list_key(trip_id: str) -> str:
    return f"dispatch:wake:{trip_id}"


async def push_dispatch_wake(trip_id: str) -> None:
    """Persist wake signal for cross-worker dispatch coordination."""
    redis = get_redis()
    key = _dispatch_wake_list_key(trip_id)
    await redis.lpush(key, "1")
    await redis.expire(key, 120)


# Backwards-compatible alias
disconnect_redis = close_redis
