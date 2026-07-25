import json
from pathlib import Path

from fastapi import APIRouter

router = APIRouter(prefix="/neighborhoods", tags=["neighborhoods"])

_DATA_PATH = Path(__file__).resolve().parents[2] / "data" / "neighborhoods.json"


@router.get("")
async def list_neighborhoods() -> list:
    with open(_DATA_PATH, encoding="utf-8") as f:
        return json.load(f)
