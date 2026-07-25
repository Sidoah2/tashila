from fastapi import APIRouter, Depends, File, Query, UploadFile
from starlette.responses import Response

from app.core.deps import require_role
from app.models.driver import (
    DriverAvailabilityUpdate,
    DriverLocationUpdate,
    DriverProfileSetup,
    DriverUpdate,
)
from app.models.push_token import PushTokenRequest
from app.services import driver_service, trip_service

router = APIRouter(prefix="/drivers", tags=["drivers"])

_driver_auth = Depends(require_role("driver"))


@router.get("/me")
async def get_me(driver: dict = _driver_auth) -> dict:
    return await driver_service.get_driver(driver["id"])


@router.put("/me")
async def update_me(body: DriverUpdate, driver: dict = _driver_auth) -> dict:
    return await driver_service.update_driver(driver["id"], body)


@router.post("/me/profile-setup")
async def profile_setup(body: DriverProfileSetup, driver: dict = _driver_auth) -> dict:
    return await driver_service.complete_profile(driver["id"], body)


@router.put("/me/avatar")
async def update_avatar(
    file: UploadFile = File(...),
    driver: dict = _driver_auth,
) -> dict:
    return await driver_service.update_avatar(driver["id"], file)


@router.put("/me/availability")
async def update_availability(
    body: DriverAvailabilityUpdate,
    driver: dict = _driver_auth,
) -> dict:
    return await driver_service.set_availability(driver["id"], body.availability)


@router.put("/me/location")
async def update_location(
    body: DriverLocationUpdate,
    driver: dict = _driver_auth,
) -> dict:
    return await driver_service.update_driver_location(driver["id"], body.lat, body.lng)


@router.get("/me/approval-status")
async def approval_status(driver: dict = _driver_auth) -> dict:
    return await driver_service.get_approval_status(driver["id"])


@router.get("/me/current-offer")
async def get_current_offer(driver: dict = _driver_auth) -> dict:
    offer = await trip_service.get_current_offer_for_driver(driver["id"])
    return {"offer": offer}


@router.get("/me/trip-requests")
async def list_trip_requests(driver: dict = _driver_auth) -> list[dict]:
    return await trip_service.get_trip_requests_for_driver(driver["id"])


@router.get("/me/active-trip")
async def get_active_trip(driver: dict = _driver_auth) -> dict:
    trip = await trip_service.get_active_trip_for_driver(driver["id"])
    return {"trip": trip}


@router.get("/me/trips")
async def list_my_trips(
    driver: dict = _driver_auth,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1),
) -> dict:
    return await driver_service.get_driver_trips(driver["id"], page, limit)


@router.get("/me/trips/{trip_id}")
async def get_my_trip(trip_id: str, driver: dict = _driver_auth) -> dict:
    return await driver_service.get_driver_trip(driver["id"], trip_id)


@router.get("/me/earnings")
async def get_earnings(driver: dict = _driver_auth) -> dict:
    return await driver_service.get_earnings(driver["id"])


@router.post("/me/documents/{doc_type}")
async def upload_document(
    doc_type: str,
    file: UploadFile = File(...),
    driver: dict = _driver_auth,
) -> dict:
    return await driver_service.upload_document(driver["id"], doc_type, file)


@router.get("/me/documents")
async def list_documents(driver: dict = _driver_auth) -> dict:
    return await driver_service.get_documents(driver["id"])


@router.post("/me/push-token")
async def register_push_token(body: PushTokenRequest, driver: dict = _driver_auth) -> dict:
    return await driver_service.upsert_push_token(driver["id"], body)


@router.delete("/me/push-token", status_code=204, response_class=Response)
async def delete_push_token(driver: dict = _driver_auth) -> Response:
    await driver_service.remove_push_token(driver["id"])
    return Response(status_code=204)
