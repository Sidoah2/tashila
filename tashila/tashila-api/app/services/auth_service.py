import logging
import random
import re
from datetime import datetime, timezone
from typing import Any

import httpx
import firebase_admin
from firebase_admin import auth as firebase_auth_sdk, credentials as firebase_credentials
from fastapi import HTTPException, status

logger = logging.getLogger(__name__)

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

# Initialize Firebase Admin SDK lazily (only once)
_firebase_app = None

def _get_firebase_app():
    global _firebase_app
    if _firebase_app is not None:
        return _firebase_app
    
    import os
    import json
    
    creds_json = os.environ.get("FIREBASE_CREDENTIALS_JSON")
    if creds_json:
        try:
            cred_dict = json.loads(creds_json)
            cred = firebase_credentials.Certificate(cred_dict)
            _firebase_app = firebase_admin.initialize_app(cred)
            return _firebase_app
        except Exception as e:
            print(f"Failed to load Firebase from FIREBASE_CREDENTIALS_JSON: {e}")
            
    creds_path = getattr(settings, "firebase_credentials_path", "firebase-adminsdk.json")
    if os.path.exists(creds_path):
        cred = firebase_credentials.Certificate(creds_path)
        _firebase_app = firebase_admin.initialize_app(cred)
    else:
        # Use application default credentials (works on Railway with env vars)
        _firebase_app = firebase_admin.initialize_app()
    return _firebase_app


async def verify_firebase_token(firebase_token: str, role: str) -> dict[str, Any]:
    """Verify a Firebase Phone Auth ID token and return our own JWT tokens."""
    if role not in ("client", "driver"):
        raise ValidationError("Role must be 'client' or 'driver'")

    try:
        _get_firebase_app()
        decoded = firebase_auth_sdk.verify_id_token(firebase_token)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid Firebase token: {e}",
        )

    phone = decoded.get("phone_number")
    if not phone:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Firebase token does not contain a phone number",
        )

    # Reuse the same user-creation/lookup logic as verify_otp
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
        if existing.get("status") == "suspended":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account suspended",
            )
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

    # Check if user/driver is suspended before sending OTP
    collection_name = USERS_COLLECTION if role == "client" else DRIVERS_COLLECTION
    collection = get_database()[collection_name]
    existing = await collection.find_one({"phone": phone})
    if existing and existing.get("status") == "suspended":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account suspended",
        )

    if not await otp_rate_limit(phone):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many OTP requests. Please try again later.",
            headers={"Retry-After": str(settings.otp_window_seconds)},
        )

    if settings.test_otp_enabled:
        otp = settings.test_otp_code
        await store_otp(phone, role, otp, ttl=120)
    elif settings.smssak_api_key and settings.smssak_project_id:
        try:
            cleaned = re.sub(r"[^\d+]", "", phone or "")
            if cleaned.startswith("+213"):
                local_phone = "0" + cleaned[4:]
                country_code = "dz"
            elif cleaned.startswith("213"):
                local_phone = "0" + cleaned[3:]
                country_code = "dz"
            elif cleaned.startswith("0") and len(cleaned) == 10:
                local_phone = cleaned
                country_code = "dz"
            elif len(cleaned) == 9 and cleaned[0] in ("5", "6", "7"):
                local_phone = "0" + cleaned
                country_code = "dz"
            else:
                local_phone = cleaned.lstrip("+")
                country_code = settings.smssak_country or "dz"

            url = "https://sendotp-47lvvvrp4a-uc.a.run.app"
            headers = {
                "Content-Type": "application/json",
                "key": settings.smssak_api_key
            }
            data = {
                "country": country_code.upper(),
                "phone": local_phone,
                "projectId": settings.smssak_project_id,
                "type": "sms"
            }
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.post(url, headers=headers, json=data)
            
            if resp.status_code not in (200, 201):
                logger.error("SMSSAK sendotp HTTP %s: %s", resp.status_code, resp.text)
                try:
                    error_detail = resp.json().get("error", "Failed to send verification SMS via provider")
                except Exception:
                    error_detail = "Failed to send verification SMS via provider"
                
                if resp.status_code in (400, 401, 403, 429):
                    raise HTTPException(
                        status_code=resp.status_code,
                        detail=error_detail,
                    )
                else:
                    raise HTTPException(
                        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                        detail=error_detail,
                    )
        except Exception as e:
            if isinstance(e, HTTPException):
                raise e
            logger.exception("SMSSAK sendotp error for %s", phone)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to send verification SMS",
            )
    else:
        otp = str(random.randint(100000, 999999))
        await store_otp(phone, role, otp, ttl=120)

        from app.services.notification_service import send_sms
        await send_sms(phone, f"Your Tashila OTP is {otp}")

    return {"expiresIn": 120}


async def verify_otp(phone: str, otp: str, role: str) -> dict[str, Any]:
    phone = _validate_phone(phone)
    if role not in ("client", "driver"):
        raise ValidationError("Role must be 'client' or 'driver'")

    otp_ok = False
    if settings.test_otp_enabled and otp == settings.test_otp_code:
        otp_ok = True

    if not otp_ok and settings.smssak_api_key and settings.smssak_project_id:
        try:
            cleaned = re.sub(r"[^\d+]", "", phone or "")
            if cleaned.startswith("+213"):
                local_phone = "0" + cleaned[4:]
                country_code = "dz"
            elif cleaned.startswith("213"):
                local_phone = "0" + cleaned[3:]
                country_code = "dz"
            elif cleaned.startswith("0") and len(cleaned) == 10:
                local_phone = cleaned
                country_code = "dz"
            elif len(cleaned) == 9 and cleaned[0] in ("5", "6", "7"):
                local_phone = "0" + cleaned
                country_code = "dz"
            else:
                local_phone = cleaned.lstrip("+")
                country_code = settings.smssak_country or "dz"

            url = "https://verifyotp-47lvvvrp4a-uc.a.run.app"
            headers = {
                "Content-Type": "application/json",
                "key": settings.smssak_api_key
            }
            data = {
                "country": country_code.upper(),
                "phone": local_phone,
                "projectId": settings.smssak_project_id,
                "otp": otp
            }
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.post(url, headers=headers, json=data)
            
            if resp.status_code in (200, 201):
                otp_ok = True
            else:
                logger.warning("SMSSAK verifyotp HTTP %s for %s: %s", resp.status_code, phone, resp.text)
        except Exception:
            logger.exception("SMSSAK verifyotp error for %s", phone)
    elif not otp_ok:
        otp_ok = await redis_verify_otp(phone, role, otp)

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
        if existing.get("status") == "suspended":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account suspended",
            )
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

    if admin.get("status", "active") == "suspended":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account suspended",
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
