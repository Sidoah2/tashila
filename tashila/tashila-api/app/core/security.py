import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import HTTPException, status
from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

ALGORITHM = "HS256"
VALID_ROLES = frozenset({"client", "driver", "admin"})


def hash_password(plain: str) -> str:
    return pwd_context.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def _build_payload(sub: str, role: str, expires_delta: timedelta) -> dict[str, Any]:
    now = datetime.now(timezone.utc)
    return {
        "sub": sub,
        "role": role,
        "iat": now,
        "exp": now + expires_delta,
        "jti": str(uuid.uuid4()),
    }


def _encode(payload: dict[str, Any], secret: str) -> str:
    return jwt.encode(payload, secret, algorithm=ALGORITHM)


def create_access_token(sub: str, role: str) -> str:
    payload = _build_payload(
        sub,
        role,
        timedelta(minutes=settings.jwt_expire_minutes),
    )
    return _encode(payload, settings.jwt_secret)


def create_refresh_token(sub: str, role: str) -> str:
    payload = _build_payload(
        sub,
        role,
        timedelta(days=settings.jwt_refresh_expire_days),
    )
    return _encode(payload, settings.jwt_refresh_secret)


def create_admin_access_token(sub: str) -> str:
    payload = _build_payload(
        sub,
        "admin",
        timedelta(minutes=settings.admin_jwt_expire_minutes),
    )
    return _encode(payload, settings.admin_jwt_secret)


def create_admin_refresh_token(sub: str) -> str:
    payload = _build_payload(
        sub,
        "admin",
        timedelta(days=settings.jwt_refresh_expire_days),
    )
    return _encode(payload, settings.admin_jwt_secret)


def decode_token(token: str, secret: str) -> dict[str, Any]:
    try:
        payload = jwt.decode(token, secret, algorithms=[ALGORITHM])
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        ) from exc

    if not payload.get("sub"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token subject",
        )
    if payload.get("role") not in VALID_ROLES:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token role",
        )
    return payload


def decode_any_token(token: str) -> dict[str, Any]:
    for secret in (settings.jwt_secret, settings.admin_jwt_secret):
        try:
            return decode_token(token, secret)
        except HTTPException:
            continue
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired token",
    )


def get_remaining_ttl(token: str, secret: str) -> int:
    try:
        claims = jwt.decode(
            token,
            secret,
            algorithms=[ALGORITHM],
            options={"verify_exp": False},
        )
    except JWTError:
        return 0

    exp = claims.get("exp")
    if exp is None:
        return 0

    if isinstance(exp, datetime):
        exp_ts = exp.timestamp()
    else:
        exp_ts = float(exp)

    remaining = int(exp_ts - datetime.now(timezone.utc).timestamp())
    return max(0, remaining)
