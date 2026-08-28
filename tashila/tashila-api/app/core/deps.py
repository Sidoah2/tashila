from collections.abc import Callable
from typing import Any, Optional

from bson import ObjectId
from bson.errors import InvalidId
from fastapi import Depends, Header, HTTPException, status

from app.core.config import settings
from app.core.database import get_database
from app.core.redis import get_redis, is_token_blacklisted, is_user_suspended
from app.core.security import decode_any_token, decode_token

USERS_COLLECTION = "users"
DRIVERS_COLLECTION = "drivers"
ADMIN_USERS_COLLECTION = "admin_users"


async def get_token_from_header(authorization: str = Header(...)) -> str:
    parts = authorization.split(" ", 1)
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header",
        )
    token = parts[1].strip()
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header",
        )
    return token


def _serialize_doc(doc: dict[str, Any]) -> dict[str, Any]:
    if "_id" in doc:
        if not isinstance(doc["_id"], str):
            doc["_id"] = str(doc["_id"])
        doc.setdefault("id", doc["_id"])
    return doc


async def _find_by_id(collection: str, subject: str) -> dict[str, Any] | None:
    try:
        object_id = ObjectId(subject)
    except (InvalidId, TypeError):
        return None

    doc = await get_database()[collection].find_one({"_id": object_id})
    if doc is None:
        return None
    return _serialize_doc(doc)


async def _ensure_not_blacklisted(jti: str | None) -> None:
    if jti and await is_token_blacklisted(jti):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has been revoked",
        )


async def _ensure_not_suspended(user_id: str) -> None:
    if await is_user_suspended(user_id):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Account suspended",
        )


async def get_current_user(token: str = Depends(get_token_from_header)) -> dict[str, Any]:
    payload = decode_token(token, settings.jwt_secret)
    await _ensure_not_blacklisted(payload.get("jti"))

    user = await _find_by_id(USERS_COLLECTION, payload["sub"])
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )
    await _ensure_not_suspended(user["id"])
    if user.get("status") == "suspended":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Account suspended",
        )
    if user.get("status") == "deleted":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Account deleted",
        )
    return user


async def get_current_driver(token: str = Depends(get_token_from_header)) -> dict[str, Any]:
    payload = decode_token(token, settings.jwt_secret)
    await _ensure_not_blacklisted(payload.get("jti"))

    driver = await _find_by_id(DRIVERS_COLLECTION, payload["sub"])
    if driver is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Driver not found",
        )
    await _ensure_not_suspended(driver["id"])
    if driver.get("status") == "suspended":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Account suspended",
        )
    if driver.get("status") == "deleted":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Account deleted",
        )
    return driver


async def get_current_admin(token: str = Depends(get_token_from_header)) -> dict[str, Any]:
    payload = decode_token(token, settings.admin_jwt_secret)
    await _ensure_not_blacklisted(payload.get("jti"))

    if payload.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token role for admin access",
        )

    admin_id = payload["sub"]
    await _ensure_not_suspended(admin_id)

    admin = await _find_by_id(ADMIN_USERS_COLLECTION, admin_id)
    if admin is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin not found",
        )
    if admin.get("status") == "suspended":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Account suspended",
        )
    return admin


def require_role(role: str) -> Callable[..., Any]:
    getters: dict[str, Callable[..., Any]] = {
        "client": get_current_user,
        "driver": get_current_driver,
        "admin": get_current_admin,
    }
    getter = getters.get(role)
    if getter is None:
        raise ValueError(f"Unknown role: {role}. Expected one of: {', '.join(getters)}")
    return getter


async def get_authenticated_principal(
    token: str = Depends(get_token_from_header),
) -> dict[str, Any]:
    """Valid access token for client, driver, or admin."""
    payload = decode_any_token(token)
    await _ensure_not_blacklisted(payload.get("jti"))
    role = payload.get("role")
    subject = payload.get("sub")
    if role == "admin":
        admin = await _find_by_id(ADMIN_USERS_COLLECTION, subject)
        if admin is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Admin not found")
        await _ensure_not_suspended(subject)
        if admin.get("status") == "suspended":
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account suspended")
        return payload
    if role == "driver":
        driver = await _find_by_id(DRIVERS_COLLECTION, subject)
        if driver is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Driver not found")
        await _ensure_not_suspended(subject)
        if driver.get("status") == "suspended":
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account suspended")
        return payload
    user = await _find_by_id(USERS_COLLECTION, subject)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    await _ensure_not_suspended(subject)
    if user.get("status") == "suspended":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account suspended")
    return payload


async def get_current_client_or_driver(
    token: str = Depends(get_token_from_header),
) -> dict[str, Any]:
    for getter in (get_current_user, get_current_driver):
        try:
            return await getter(token)
        except HTTPException:
            continue
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Not authenticated as client or driver",
    )


async def get_redis_client():
    return get_redis()


def get_idempotency_key(
    x_idempotency_key: Optional[str] = Header(default=None, alias="X-Idempotency-Key"),
) -> Optional[str]:
    return x_idempotency_key
