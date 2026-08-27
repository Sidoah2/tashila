from typing import Any

from fastapi import APIRouter, Depends

from app.core.deps import get_current_admin, require_role
from app.models.admin import AdminAccountStatusUpdate, AdminCreate, AdminProfileUpdate
from app.services import admin_service

router = APIRouter(prefix="/admin/accounts", tags=["admin-accounts"])

_admin_auth = Depends(require_role("admin"))


def _require_super_admin(admin: dict[str, Any] = Depends(get_current_admin)) -> dict[str, Any]:
    from fastapi import HTTPException, status as http_status
    if admin.get("role") != "super_admin":
        raise HTTPException(
            status_code=http_status.HTTP_403_FORBIDDEN,
            detail="Super admin access required",
        )
    return admin


@router.get("", dependencies=[Depends(_require_super_admin)])
async def list_admins() -> list:
    return await admin_service.admin_list_admins()


@router.post("", status_code=201)
async def create_admin(
    body: AdminCreate,
    _: dict = Depends(_require_super_admin),
) -> dict:
    return await admin_service.admin_create_admin(body.model_dump())


@router.put("/{admin_id}/status")
async def update_admin_status(
    admin_id: str,
    body: AdminAccountStatusUpdate,
    _: dict = Depends(_require_super_admin),
) -> dict:
    return await admin_service.admin_update_admin_status(admin_id, body)


@router.put("/me/profile")
async def update_my_profile(
    body: AdminProfileUpdate,
    admin: dict = Depends(get_current_admin),
) -> dict:
    return await admin_service.admin_update_my_profile(admin, body)
