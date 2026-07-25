from datetime import datetime

from fastapi import APIRouter, Depends, Query

from app.core.deps import require_role
from app.core.exceptions import ValidationError
from app.services import stats_service

router = APIRouter(prefix="/admin/stats", tags=["admin-stats"])

_admin_auth = Depends(require_role("admin"))

REVENUE_RANGES: dict[str, int] = {
    "7d": 7,
    "14d": 14,
    "30d": 30,
    "90d": 90,
}


def _parse_date(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ValidationError(f"Invalid date: {value}") from exc


@router.get("/dashboard")
async def dashboard(
    _admin: dict = _admin_auth,
    from_date: str | None = Query(default=None, alias="from"),
    to_date: str | None = Query(default=None, alias="to"),
) -> dict:
    return await stats_service.get_dashboard_kpis(
        from_date=_parse_date(from_date),
        to_date=_parse_date(to_date),
    )


@router.get("/revenue")
async def revenue_chart(
    _admin: dict = _admin_auth,
    range: str = Query("14d", alias="range"),
    from_date: str | None = Query(default=None, alias="from"),
    to_date: str | None = Query(default=None, alias="to"),
) -> dict:
    parsed_from = _parse_date(from_date)
    parsed_to = _parse_date(to_date)
    if parsed_from is not None:
        return await stats_service.get_revenue_chart(
            from_date=parsed_from,
            to_date=parsed_to,
        )
    days = REVENUE_RANGES.get(range)
    if days is None:
        raise ValidationError("range must be one of: 7d, 14d, 30d, 90d")
    return await stats_service.get_revenue_chart(range_days=days)


@router.get("/top-drivers")
async def top_drivers(
    _admin: dict = _admin_auth,
    limit: int = Query(10, ge=1, le=50),
    from_date: str | None = Query(default=None, alias="from"),
    to_date: str | None = Query(default=None, alias="to"),
) -> list:
    return await stats_service.get_top_drivers(
        limit,
        from_date=_parse_date(from_date),
        to_date=_parse_date(to_date),
    )


@router.get("/pending-approvals")
async def pending_approvals(_admin: dict = _admin_auth) -> dict:
    return await stats_service.get_pending_approvals_count()
