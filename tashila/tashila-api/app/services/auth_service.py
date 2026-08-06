import random
import re
from datetime import datetime, timezone
from typing import Any

from fastapi import HTTPException, status

from app.core.config import settings
from app.core.database import get_database
from app.core.exceptions import ValidationError
from app.core.redis import (
    blacklist_token,
    is_token_blacklisted,
    otp_rate_limit,
    store_otp,
    verify_otp as redis_verify_otp,
)
from app.core.security import (
    create_access_token,
    create_admin_access_token,
    create_admin_refresh_token,
    create_refresh_token,
    decode_token,
    get_remaining_ttl,
    verify_password,
)

PHONE_PATTERN = re.compile(r"^\+\d{8,15}$")

# =============================================================================
import os
_TEST_OTP_ENABLED = True
_TEST_OTP_CODE = "111111"
# =============================================================================

USERS_COLLECTION = "users"
DRIVERS_COLLECTION = "drivers"
ADMIN_USERS_COLLECTION = "admin_users"


def _clean_phone(phone: str) -> str:
    cleaned = re.sub(r"[^\d+]", "", phone or "")
    if cleaned and not cleaned.startswith("+"):
        cleaned = "+" + cleaned
    return cleaned


def _validate_phone(phone: str) -> str:
    cleaned = _clean_phone(phone)
    if not cleaned or len(cleaned) < 5:
        raise ValidationError("Phone number must contain at least 5 digits")
    return cleaned


async def send_otp(phone: str, role: str) -> dict[str, int]:
    phone = _validate_phone(phone)
    if role not in ("client", "driver"):
        raise ValidationError("Role must be 'client' or 'driver'")

    if not await otp_rate_limit(phone):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many OTP requests. Please try again later.",
            headers={"Retry-After": str(settings.otp_window_seconds)},
        )

    if _TEST_OTP_ENABLED:
        otp = _TEST_OTP_CODE
    else:
        otp = str(random.randint(100000, 999999))
    await store_otp(phone, role, otp, ttl=120)

    from app.services.notification_service import send_sms

    if not _TEST_OTP_ENABLED:
        await send_sms(phone, f"Your Tashila OTP is {otp}")

    return {"expiresIn": 120}


async def verify_otp(phone: str, otp: str, role: str) -> dict[str, Any]:
    phone = _validate_phone(phone)
    if role not in ("client", "driver"):
        raise ValidationError("Role must be 'client' or 'driver'")

    otp_ok = (_TEST_OTP_ENABLED and otp == _TEST_OTP_CODE) or await redis_verify_otp(
        phone, role, otp
    )
    if not otp_ok:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired OTP",
        )

    collection_name = USERS_COLLECTION if role == "client" else DRIVERS_COLLECTION
    collection = get_database()[collection_name]
    now = datetime.now(timezone.utc)

    existing = await collection.find_one({"phone": phone})
    if existing is None:
        new_doc: dict[str, Any] = {
            "phone": phone,
            "createdAt": now,
            "updatedAt": now,
            "profileComplete": False,
            "status": "active",
        }
        if role == "driver":
            new_doc["truckType"] = ""
            new_doc["availability"] = "offline"
            new_doc["approvalStatus"] = "pending"
        result = await collection.insert_one(new_doc)
        user_id = str(result.inserted_id)
        profile_complete = False
    else:
        user_id = str(existing["_id"])
        profile_complete = existing.get("profileComplete", False)
        await collection.update_one(
            {"_id": existing["_id"]},
            {"$set": {"updatedAt": now}},
        )

    access_token = create_access_token(user_id, role)
    refresh_token = create_refresh_token(user_id, role)

    return {
        "accessToken": access_token,
        "refreshToken": refresh_token,
        "user": {
            "id": user_id,
            "phone": phone,
            "profileComplete": profile_complete,
        },
    }


async def refresh_token(refresh_token_value: str, secret: str) -> dict[str, str]:
    payload = decode_token(refresh_token_value, secret)
    jti = payload.get("jti")
    if jti and await is_token_blacklisted(jti):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has been revoked",
        )

    ttl = get_remaining_ttl(refresh_token_value, secret)
    if jti and ttl > 0:
        await blacklist_token(jti, ttl)

    access_token = create_access_token(payload["sub"], payload["role"])
    new_refresh = create_refresh_token(payload["sub"], payload["role"])
    return {"accessToken": access_token, "refreshToken": new_refresh}


async def logout(token: str, secret: str) -> None:
    payload = decode_token(token, secret)
    jti = payload.get("jti")
    if not jti:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )
    ttl = get_remaining_ttl(token, secret)
    if ttl > 0:
        await blacklist_token(jti, ttl)


async def admin_login(email: str, password: str) -> dict[str, Any]:
    admin = await get_database()[ADMIN_USERS_COLLECTION].find_one({"email": email})
    if admin is None or not verify_password(password, admin.get("passwordHash", "")):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    admin_id = str(admin["_id"])
    return {
        "accessToken": create_admin_access_token(admin_id),
        "refreshToken": create_admin_refresh_token(admin_id),
        "admin": {
            "id": admin_id,
            "email": admin["email"],
            "name": admin.get("name", ""),
            "role": admin.get("role", "admin"),
        },
    }


async def admin_logout(token: str) -> None:
    await logout(token, settings.admin_jwt_secret)


def admin_me_response(admin: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": admin.get("id") or admin.get("_id"),
        "email": admin.get("email"),
        "name": admin.get("name", ""),
        "role": admin.get("role", "admin"),
        "createdAt": admin.get("createdAt"),
    }
