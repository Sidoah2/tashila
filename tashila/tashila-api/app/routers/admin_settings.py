from fastapi import APIRouter, Depends

from app.core.deps import require_role
from app.models.platform_settings import PlatformSettingsResponse, PlatformSettingsUpdate
from app.services import platform_settings_service

router = APIRouter(prefix="/admin/settings", tags=["admin-settings"])

_admin_auth = Depends(require_role("admin"))


@router.get("", response_model=PlatformSettingsResponse)
async def get_settings(_admin: dict = _admin_auth) -> dict:
    doc = await platform_settings_service.get_platform_settings()
    return {
        "commissionRate": doc.get("commissionRate", 0.10),
        "serviceAreaCenter": doc.get("serviceAreaCenter", {"lat": 22.785, "lng": 5.523}),
        "serviceAreaRadiusKm": doc.get("serviceAreaRadiusKm", 50.0),
    }


@router.put("", response_model=PlatformSettingsResponse)
async def update_settings(
    body: PlatformSettingsUpdate,
    _admin: dict = _admin_auth,
) -> dict:
    doc = await platform_settings_service.update_platform_settings(body)
    return {
        "commissionRate": doc.get("commissionRate", 0.10),
        "serviceAreaCenter": doc.get("serviceAreaCenter", {"lat": 22.785, "lng": 5.523}),
        "serviceAreaRadiusKm": doc.get("serviceAreaRadiusKm", 50.0),
    }
