from fastapi import APIRouter
from app.services import platform_settings_service

router = APIRouter(prefix="/settings", tags=["settings"])


@router.get("")
async def get_public_settings() -> dict:
    doc = await platform_settings_service.get_platform_settings()
    return {
        "serviceAreaCenter": doc.get("serviceAreaCenter", {"lat": 22.785, "lng": 5.523}),
        "serviceAreaRadiusKm": doc.get("serviceAreaRadiusKm", 200.0),
    }
