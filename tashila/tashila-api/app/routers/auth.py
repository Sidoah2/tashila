from typing import Literal

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict
from starlette.responses import Response

from app.core.config import settings
from app.core.deps import get_current_admin, get_token_from_header
from app.core.redis import get_redis
from app.services import auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


class SendOtpRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    phone: str
    role: Literal["client", "driver"]


class VerifyOtpRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    phone: str
    otp: str
    role: Literal["client", "driver"]


class RefreshTokenRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    refreshToken: str


class AdminLoginRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    email: str
    password: str


@router.post("/otp/send", status_code=status.HTTP_200_OK)
async def send_otp(body: SendOtpRequest) -> dict[str, int]:
    return await auth_service.send_otp(body.phone, body.role)


@router.post("/otp/verify", status_code=status.HTTP_200_OK)
async def verify_otp(body: VerifyOtpRequest) -> dict:
    return await auth_service.verify_otp(body.phone, body.otp, body.role)


@router.post("/token/refresh", status_code=status.HTTP_200_OK)
async def refresh_access_token(body: RefreshTokenRequest) -> dict[str, str]:
    return await auth_service.refresh_token(body.refreshToken, settings.jwt_refresh_secret)


@router.post("/admin/refresh", status_code=status.HTTP_200_OK)
async def admin_refresh_access_token(body: RefreshTokenRequest) -> dict[str, str]:
    return await auth_service.refresh_token(body.refreshToken, settings.admin_jwt_secret)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT, response_class=Response)
async def logout(token: str = Depends(get_token_from_header)) -> Response:
    await auth_service.logout(token, settings.jwt_secret)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/admin/login", status_code=status.HTTP_200_OK)
async def admin_login(body: AdminLoginRequest) -> dict:
    return await auth_service.admin_login(body.email, body.password)


@router.post("/admin/logout", status_code=status.HTTP_204_NO_CONTENT, response_class=Response)
async def admin_logout(token: str = Depends(get_token_from_header)) -> Response:
    await auth_service.admin_logout(token)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/admin/me", status_code=status.HTTP_200_OK)
async def admin_me(admin: dict = Depends(get_current_admin)) -> dict:
    return auth_service.admin_me_response(admin)


@router.get("/sim/otp", status_code=status.HTTP_200_OK, tags=["simulation"])
async def sim_get_otp(
    phone: str = Query(...),
    role: Literal["client", "driver"] = Query(...),
    x_sim_secret: str = Header(..., alias="X-Sim-Secret"),
) -> dict:
    """Return the current Redis OTP for a phone/role pair. Only active when SIMULATION_OTP_SECRET is set."""
    sim_secret = getattr(settings, "simulation_otp_secret", "") or ""
    if not sim_secret:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    if x_sim_secret != sim_secret:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
    key = f"otp:{role}:{phone}"
    otp = await get_redis().get(key)
    if not otp:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="OTP not found or expired")
    return {"otp": otp}
