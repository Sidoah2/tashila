import os
import sys
from collections.abc import AsyncGenerator
from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

if sys.version_info < (3, 12):
    pytest.skip("Requires Python 3.12+ (see runtime.txt)", allow_module_level=True)

# Minimal env for Settings validation before app import
os.environ.setdefault("MONGO_URI", "mongodb://localhost:27017")
os.environ.setdefault("MONGO_DB_NAME", "tashila_test")
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/0")
os.environ.setdefault(
    "JWT_SECRET",
    "test_jwt_secret_minimum_32_characters_long",
)
os.environ.setdefault(
    "JWT_REFRESH_SECRET",
    "test_refresh_secret_minimum_32_chars",
)
os.environ.setdefault(
    "ADMIN_JWT_SECRET",
    "test_admin_secret_minimum_32_chars_xx",
)
os.environ.setdefault("ENVIRONMENT", "development")


@pytest.fixture
def anyio_backend() -> str:
    return "asyncio"


@pytest.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    async def _noop_bridge() -> None:
        return

    with (
        patch("app.main.connect_db", new_callable=AsyncMock),
        patch("app.main.close_db", new_callable=AsyncMock),
        patch("app.main.connect_redis", new_callable=AsyncMock),
        patch("app.main.close_redis", new_callable=AsyncMock),
        patch("app.main.start_redis_bridge", side_effect=_noop_bridge),
    ):
        from app.main import app as fastapi_app

        transport = ASGITransport(app=fastapi_app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            yield ac
