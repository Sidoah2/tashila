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
    is_admin_login_locked,
    is_otp_verify_locked,
    is_token_blacklisted,
    otp_rate_limit,
    record_admin_login_failure,
    record_otp_verify_failure,
    reset_admin_login_failures,
    reset_otp_verify_failures,
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
    if not cleaned:
        return ""
    digits = re.sub(r"\D", "", cleaned)
    # If Algerian mobile number starting with 05, 06, 07 and 10 digits
    if digits.startswith("0") and len(digits) == 10 and digits[1] in ("5", "6", "7"):
        return f"+213{digits[1:]}"
    # If starting with 213 (e.g. 213611223344 or 2130611223344)
    if digits.startswith("213"):
        rest = digits[3:]
        if rest.startswith("0"):
            rest = rest[1:]
        return f"+213{rest}"
    # If 9 digits starting with 5, 6, 7
    if len(digits) == 9 and digits[0] in ("5", "6", "7"):
        return f"+213{digits}"
    if not cleaned.startswith("+"):
        cleaned = "+" + cleaned
    return cleaned


def _validate_phone(phone: str) -> str:
    cleaned = _clean_phone(phone)
    if not cleaned or len(cleaned) < 5:
        raise ValidationError("Phone number must contain at least 5 digits")
    return cleaned


TEST_PHONE_SUFFIXES = ("611223344", "711223344")


def _get_test_phones() -> set[str]:
    phones = {
        "+213611223344",
        "+213711223344",
        "0611223344",
        "0711223344",
        "611223344",
        "711223344",
    }
    configured = getattr(settings, "test_phone_numbers", "")
    if configured:
        for p in configured.split(","):
            p_clean = p.strip()
            if p_clean:
                phones.add(p_clean)
                digits = re.sub(r"\D", "", p_clean)
                if digits:
                    phones.add(digits)
    return phones


def is_test_phone(phone: str) -> bool:
    digits = re.sub(r"\D", "", phone or "")
    if any(digits.endswith(suffix) for suffix in TEST_PHONE_SUFFIXES):
        return True
    if phone in _get_test_phones() or digits in _get_test_phones():
        return True
    return False


def _get_test_otp_codes() -> set[str]:
    codes = {"1111", "1234", "0000"}
    if settings.test_otp_code:
        codes.add(str(settings.test_otp_code).strip())
    configured = getattr(settings, "test_otp_codes", "")
    if configured:
        for c in configured.split(","):
            c_clean = c.strip()
            if c_clean:
                codes.add(c_clean)
    return codes


def _phone_query(phone: str) -> dict[str, Any]:
    digits = re.sub(r"\D", "", phone or "")
    candidates = [phone]
    if digits:
        candidates.append(f"+{digits}")
        candidates.append(digits)
        if digits.startswith("213"):
            local = "0" + digits[3:]
            candidates.append(local)
            candidates.append(f"+{digits}")
        elif digits.startswith("0") and len(digits) == 10:
            intl = "+213" + digits[1:]
            candidates.append(intl)
        if len(digits) >= 9:
            last9 = digits[-9:]
            candidates.extend([f"+213{last9}", f"0{last9}", last9])
    seen = set()
    uniq = []
    for c in candidates:
        if c and c not in seen:
            seen.add(c)
            uniq.append(c)
    return {"phone": {"$in": uniq}}


async def send_otp(phone: str, role: str) -> dict[str, int]:
    phone = _validate_phone(phone)
    if role not in ("client", "driver"):
        raise ValidationError("Role must be 'client' or 'driver'")

    # Dedicated store reviewer test accounts bypass SMS and rate limiting
    if is_test_phone(phone):
        test_code = settings.test_otp_code or "1111"
        await store_otp(phone, role, test_code, ttl=3600)
        logger.info("Store review test account OTP requested for phone=%s, role=%s (test OTP: %s)", phone, role, test_code)
        return {"expiresIn": 3600}

    # Check if user/driver is suspended before sending OTP
    collection_name = USERS_COLLECTION if role == "client" else DRIVERS_COLLECTION
    collection = get_database()[collection_name]
    existing = await collection.find_one(_phone_query(phone))
    if existing and existing.get("status") == "suspended":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account suspended",
        )

    if not await otp_rate_limit(phone):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many OTP requests. Please try again later.",
            headers={"Retry-After": str(getattr(settings, "otp_window_seconds", 60))},
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

            url = settings.smssak_send_otp_url or "https://sendotp-47lvvvrp4a-uc.a.run.app"
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

    # C5: Check brute-force lockout before checking OTP
    if await is_otp_verify_locked(phone):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many failed verification attempts. Please wait 5 minutes before trying again.",
        )

    otp_ok = False
    is_test = is_test_phone(phone)

    if is_test:
        if otp in _get_test_otp_codes():
            otp_ok = True
        elif settings.test_otp_enabled and otp == settings.test_otp_code:
            otp_ok = True
        else:
            otp_ok = await redis_verify_otp(phone, role, otp)
    elif settings.test_otp_enabled and otp == settings.test_otp_code:
        otp_ok = True
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

            # H3: Use configurable smssak_verify_otp_url
            url = settings.smssak_verify_otp_url or "https://verifyotp-47lvvvrp4a-uc.a.run.app"
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
        # C5: Record failed attempt and lock out if threshold reached
        attempts = await record_otp_verify_failure(
            phone,
            max_attempts=settings.max_otp_attempts,
            lockout_seconds=300,
        )
        remaining = max(0, settings.max_otp_attempts - attempts)
        if remaining == 0:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many failed verification attempts. Account locked for 5 minutes.",
            )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid or expired OTP. {remaining} attempt(s) remaining.",
        )

    # Success: reset failed attempt counter
    await reset_otp_verify_failures(phone)

    collection_name = USERS_COLLECTION if role == "client" else DRIVERS_COLLECTION
    collection = get_database()[collection_name]
    now = datetime.now(timezone.utc)

    existing = await collection.find_one(_phone_query(phone))

    if is_test:
        if role == "client":
            if existing is None:
                new_doc: dict[str, Any] = {
                    "phone": phone,
                    "name": "Test Client",
                    "email": "testclient@tashila.dz",
                    "locale": "ar",
                    "createdAt": now,
                    "updatedAt": now,
                    "profileComplete": True,
                    "status": "active",
                }
                result = await collection.insert_one(new_doc)
                user_id = str(result.inserted_id)
            else:
                user_id = str(existing["_id"])
                update_fields: dict[str, Any] = {
                    "status": "active",
                    "profileComplete": True,
                    "updatedAt": now,
                }
                if not existing.get("name"):
                    update_fields["name"] = "Test Client"
                if not existing.get("locale"):
                    update_fields["locale"] = "ar"
                await collection.update_one({"_id": existing["_id"]}, {"$set": update_fields})
            profile_complete = True
        else:  # role == "driver"
            sample_docs = {
                "drivingLicense": {
                    "url": "https://images.unsplash.com/photo-1544620347-c4fd4a3d5957",
                    "status": "approved",
                    "uploadedAt": now,
                    "rejectionReason": None,
                },
                "vehicleRegistration": {
                    "url": "https://images.unsplash.com/photo-1544620347-c4fd4a3d5957",
                    "status": "approved",
                    "uploadedAt": now,
                    "rejectionReason": None,
                },
                "vehiclePhoto": {
                    "url": "https://images.unsplash.com/photo-1544620347-c4fd4a3d5957",
                    "status": "approved",
                    "uploadedAt": now,
                    "rejectionReason": None,
                },
            }
            if existing is None:
                new_doc = {
                    "phone": phone,
                    "name": "Test Driver",
                    "email": "testdriver@tashila.dz",
                    "truckType": "single_cabin",
                    "vehiclePlate": "00123-116-16",
                    "vehicleColor": "Blanc",
                    "vehicleModel": "Toyota Hilux",
                    "availability": "offline",
                    "approvalStatus": "approved",
                    "rejectionReason": None,
                    "documents": sample_docs,
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
                result = await collection.insert_one(new_doc)
                user_id = str(result.inserted_id)
            else:
                user_id = str(existing["_id"])
                docs = existing.get("documents") or {}
                merged_docs = dict(sample_docs)
                merged_docs.update(docs)
                update_fields = {
                    "status": "active",
                    "approvalStatus": "approved",
                    "rejectionReason": None,
                    "profileComplete": True,
                    "documents": merged_docs,
                    "updatedAt": now,
                }
                if not existing.get("name"):
                    update_fields["name"] = "Test Driver"
                if not existing.get("truckType"):
                    update_fields["truckType"] = "single_cabin"
                if not existing.get("vehiclePlate"):
                    update_fields["vehiclePlate"] = "00123-116-16"
                if not existing.get("vehicleModel"):
                    update_fields["vehicleModel"] = "Toyota Hilux"
                if not existing.get("vehicleColor"):
                    update_fields["vehicleColor"] = "Blanc"
                await collection.update_one({"_id": existing["_id"]}, {"$set": update_fields})
            profile_complete = True
    else:
        if existing is None:
            new_doc = {
                "phone": phone,
                "locale": "ar",
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

    role = payload.get("role")
    sub = payload.get("sub")
    if sub:
        from app.core.deps import _ensure_not_suspended
        await _ensure_not_suspended(sub)
        
        from app.core.database import get_database
        from bson import ObjectId
        if role == "admin":
            admin = await get_database()["admin_users"].find_one({"_id": ObjectId(sub)})
            if admin and admin.get("status") == "suspended":
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account suspended")
        elif role == "driver":
            driver = await get_database()["drivers"].find_one({"_id": ObjectId(sub)})
            if driver and driver.get("status") == "suspended":
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account suspended")
        elif role == "client":
            user = await get_database()["users"].find_one({"_id": ObjectId(sub)})
            if user and user.get("status") == "suspended":
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account suspended")

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
    # C6: Check admin brute-force lockout
    if await is_admin_login_locked(email):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many failed admin login attempts. Account temporarily locked for 15 minutes.",
        )

    admin = await get_database()[ADMIN_USERS_COLLECTION].find_one({"email": email})
    if admin is None or not verify_password(password, admin.get("passwordHash", "")):
        await record_admin_login_failure(email, max_attempts=5, lockout_seconds=900)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    if admin.get("status", "active") == "suspended":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account suspended",
        )

    # Success: clear failure counter
    await reset_admin_login_failures(email)

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
