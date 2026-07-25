import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health(client: AsyncClient) -> None:
    response = await client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert "timestamp" in data
    assert data["environment"] == "development"


@pytest.mark.asyncio
async def test_ready_reports_dependency_status(client: AsyncClient) -> None:
    from unittest.mock import AsyncMock, patch

    with (
        patch("app.main.mongo_health_check", AsyncMock(return_value=True)),
        patch("app.main.redis_health_check", AsyncMock(return_value=True)),
    ):
        response = await client.get("/ready")

    assert response.status_code == 200
    assert response.json() == {"mongo": True, "redis": True, "ok": True}
