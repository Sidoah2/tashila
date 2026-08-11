from fastapi import APIRouter, Depends, Query
from starlette.responses import Response

from app.core.deps import get_current_client_or_driver, get_idempotency_key, require_role
from app.models.trip import RatingRequest, TripCreateRequest, TripEstimateRequest, TripStatusUpdate
from app.services import trip_service

router = APIRouter(prefix="/trips", tags=["trips"])

_client_auth = Depends(require_role("client"))
_driver_auth = Depends(require_role("driver"))


@router.post("/estimate")
async def estimate_trip(
    body: TripEstimateRequest,
    bypass_service_area: bool = Query(default=False),
    _user: dict = _client_auth,
) -> dict:
    return await trip_service.estimate_trip(
        body.pickup,
        body.dropoff,
        body.truckType,
        bypass_service_area=bypass_service_area,
    )


@router.post("", status_code=201)
async def create_trip(
    body: TripCreateRequest,
    user: dict = _client_auth,
    idempotency_key: str | None = Depends(get_idempotency_key),
) -> dict:
    return await trip_service.create_trip(user["id"], body, idempotency_key=idempotency_key)


@router.get("/{trip_id}")
async def get_trip(
    trip_id: str,
    principal: dict = Depends(get_current_client_or_driver),
) -> dict:
    return await trip_service.get_trip_for_principal(trip_id, principal)


@router.delete("/{trip_id}", status_code=204, response_class=Response)
async def cancel_trip(
    trip_id: str,
    user: dict = _client_auth,
    reason: str | None = Query(default=None),
) -> Response:
    await trip_service.cancel_trip(trip_id, user["id"], reason)
    return Response(status_code=204)


@router.post("/{trip_id}/rate-driver")
async def rate_driver(
    trip_id: str,
    body: RatingRequest,
    user: dict = _client_auth,
) -> dict:
    return await trip_service.rate_driver(
        trip_id,
        user["id"],
        body.rating,
        body.comment,
    )


@router.post("/{trip_id}/accept")
async def accept_trip(trip_id: str, driver: dict = _driver_auth) -> dict:
    return await trip_service.accept_trip(trip_id, driver["id"])


@router.post("/{trip_id}/reject", status_code=204, response_class=Response)
async def reject_trip(trip_id: str, driver: dict = _driver_auth) -> Response:
    await trip_service.reject_trip(trip_id, driver["id"])
    return Response(status_code=204)


@router.put("/{trip_id}/status")
async def update_trip_status(
    trip_id: str,
    body: TripStatusUpdate,
    driver: dict = _driver_auth,
) -> dict:
    return await trip_service.advance_trip_status(trip_id, driver["id"], body.status)


@router.post("/{trip_id}/rate-client")
async def rate_client(
    trip_id: str,
    body: RatingRequest,
    driver: dict = _driver_auth,
) -> dict:
    return await trip_service.rate_client(
        trip_id,
        driver["id"],
        body.rating,
        body.comment,
    )


@router.post("/{trip_id}/driver-cancel")
async def driver_cancel_trip(
    trip_id: str,
    driver: dict = _driver_auth,
    reason: str | None = Query(default=None),
) -> dict:
    return await trip_service.driver_cancel_trip(trip_id, driver["id"], reason)
