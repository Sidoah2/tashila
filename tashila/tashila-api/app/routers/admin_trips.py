from datetime import datetime

from fastapi import APIRouter, Depends, Query

from app.core.deps import require_role
from app.models.trip import AdminTripDispatchRequest, AdminTripStatusUpdate
from app.services import trip_service

router = APIRouter(prefix="/admin/trips", tags=["admin-trips"])

_admin_auth = Depends(require_role("admin"))


@router.get("")
async def list_trips(
    _admin: dict = _admin_auth,
    status: str | None = Query(default=None),
    driverId: str | None = Query(default=None),
    clientId: str | None = Query(default=None),
    from_: datetime | None = Query(default=None, alias="from"),
    to: datetime | None = Query(default=None),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1),
) -> dict:
    return await trip_service.admin_list_trips(
        status=status,
        driver_id=driverId,
        client_id=clientId,
        from_dt=from_.isoformat() if from_ else None,
        to_dt=to.isoformat() if to else None,
        page=page,
        limit=limit,
    )


@router.post("/dispatch", status_code=201)
async def dispatch_trip(body: AdminTripDispatchRequest, _admin: dict = _admin_auth) -> dict:
    return await trip_service.admin_dispatch_trip(body)


@router.get("/{trip_id}")
async def get_trip(trip_id: str, _admin: dict = _admin_auth) -> dict:
    return await trip_service.admin_get_trip(trip_id)


@router.put("/{trip_id}/status")
async def force_trip_status(
    trip_id: str,
    body: AdminTripStatusUpdate,
    _admin: dict = _admin_auth,
) -> dict:
    return await trip_service.admin_force_status(trip_id, body.status)


@router.put("/{trip_id}/cash-confirm")
async def cash_confirm(trip_id: str, _admin: dict = _admin_auth) -> dict:
    return await trip_service.admin_cash_confirm(trip_id)


@router.delete("/{trip_id}")
async def delete_trip(trip_id: str, _admin: dict = _admin_auth) -> dict:
    return await trip_service.admin_delete_trip(trip_id)
