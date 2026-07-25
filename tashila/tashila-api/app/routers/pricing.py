from fastapi import APIRouter, Depends

from app.core.deps import require_role
from app.models.pricing import PricingUpdate
from app.services import pricing_service

router = APIRouter(tags=["pricing"])


@router.get("/pricing")
async def list_pricing() -> list[dict]:
    return await pricing_service.get_all_pricing()


@router.get("/pricing/{truck_type}")
async def get_pricing(truck_type: str) -> dict:
    return await pricing_service.get_pricing_by_truck(truck_type)


@router.put("/admin/pricing/{truck_type}")
async def admin_update_pricing(
    truck_type: str,
    body: PricingUpdate,
    _admin: dict = Depends(require_role("admin")),
) -> dict:
    return await pricing_service.update_pricing(truck_type, body)
