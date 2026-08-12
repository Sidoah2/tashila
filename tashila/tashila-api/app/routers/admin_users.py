from fastapi import APIRouter, Depends, File, Query, UploadFile

from app.core.deps import require_role
from app.models.admin import (
    AdminDocumentStatusUpdate,
    AdminDriverApprovalUpdate,
    AdminDriverAvailabilityUpdate,
    AdminDriverCreate,
    AdminDriverPaymentCreate,
    AdminUserStatusUpdate,
)
from app.services import admin_service, upload_service

_admin_auth = Depends(require_role("admin"))

users_router = APIRouter(prefix="/admin/users", tags=["admin-users"])
drivers_router = APIRouter(prefix="/admin/drivers", tags=["admin-drivers"])


@users_router.get("")
async def list_users(
    _admin: dict = _admin_auth,
    search: str | None = Query(default=None),
    status: str | None = Query(default=None),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
) -> dict:
    return await admin_service.admin_list_users(
        search=search,
        status=status,
        page=page,
        limit=limit,
    )


@users_router.get("/{user_id}")
async def get_user(user_id: str, _admin: dict = _admin_auth) -> dict:
    return await admin_service.admin_get_user(user_id)


@users_router.put("/{user_id}/status")
async def update_user_status(
    user_id: str,
    body: AdminUserStatusUpdate,
    _admin: dict = _admin_auth,
) -> dict:
    return await admin_service.admin_update_user_status(user_id, body)


@drivers_router.get("")
async def list_drivers(
    _admin: dict = _admin_auth,
    approval: str | None = Query(default=None),
    availability: str | None = Query(default=None),
    truckType: str | None = Query(default=None),
    search: str | None = Query(default=None),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
) -> dict:
    return await admin_service.admin_list_drivers(
        approval=approval,
        availability=availability,
        truck_type=truckType,
        search=search,
        page=page,
        limit=limit,
    )


@drivers_router.get("/pending-approval")
async def list_pending_drivers(_admin: dict = _admin_auth) -> list:
    return await admin_service.admin_list_pending_drivers()


@drivers_router.get("/{driver_id}")
async def get_driver(driver_id: str, _admin: dict = _admin_auth) -> dict:
    return await admin_service.admin_get_driver(driver_id)


@drivers_router.post("", status_code=201)
async def create_driver(body: AdminDriverCreate, _admin: dict = _admin_auth) -> dict:
    return await admin_service.admin_create_driver(body)


@drivers_router.put("/{driver_id}/status")
async def update_driver_status(
    driver_id: str,
    body: AdminUserStatusUpdate,
    _admin: dict = _admin_auth,
) -> dict:
    return await admin_service.admin_update_driver_status(driver_id, body)


@drivers_router.put("/{driver_id}/approval")
async def update_driver_approval(
    driver_id: str,
    body: AdminDriverApprovalUpdate,
    _admin: dict = _admin_auth,
) -> dict:
    return await admin_service.admin_update_driver_approval(driver_id, body)


@drivers_router.put("/{driver_id}/documents/{doc_type}/status")
async def update_document_status(
    driver_id: str,
    doc_type: str,
    body: AdminDocumentStatusUpdate,
    _admin: dict = _admin_auth,
) -> dict:
    return await admin_service.admin_update_document_status(driver_id, doc_type, body)


@drivers_router.put("/{driver_id}/availability")
async def force_driver_availability(
    driver_id: str,
    body: AdminDriverAvailabilityUpdate,
    _admin: dict = _admin_auth,
) -> dict:
    return await admin_service.admin_force_driver_availability(driver_id, body)


@users_router.get("/{user_id}/reviews")
async def get_user_reviews(user_id: str, _admin: dict = _admin_auth) -> list:
    return await admin_service.admin_get_user_reviews(user_id)


@drivers_router.get("/{driver_id}/reviews")
async def get_driver_reviews(driver_id: str, _admin: dict = _admin_auth) -> list:
    return await admin_service.admin_get_driver_reviews(driver_id)


@drivers_router.post("/{driver_id}/documents/{doc_type}/upload")
async def upload_driver_document(
    driver_id: str,
    doc_type: str,
    _admin: dict = _admin_auth,
    file: UploadFile = File(...),
) -> dict:
    return await admin_service.admin_upload_driver_document(driver_id, doc_type, file)


@drivers_router.post("/{driver_id}/avatar")
async def upload_driver_avatar(
    driver_id: str,
    _admin: dict = _admin_auth,
    file: UploadFile = File(...),
) -> dict:
    return await admin_service.admin_upload_driver_avatar(driver_id, file)



@drivers_router.post("/{driver_id}/payments", status_code=201)
async def record_driver_payment(
    driver_id: str,
    body: AdminDriverPaymentCreate,
    admin: dict = _admin_auth,
) -> dict:
    return await admin_service.admin_record_driver_payment(driver_id, admin, body)


router = APIRouter()
router.include_router(users_router)
router.include_router(drivers_router)
