import asyncio
import logging
import uuid
from pathlib import Path
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone

import socketio
from fastapi import FastAPI, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from app.core.config import settings
from app.core.database import close_db, connect_db, get_database, health_check as mongo_health_check
from app.core.exceptions import register_exception_handlers
from app.core.logging import setup_logging
from app.core.redis import close_redis, connect_redis, redis_health_check
from app.routers import (
    admin_settings,
    admin_stats,
    admin_trips,
    admin_users,
    auth,
    drivers,
    pricing,
    trips,
    uploads,
    users,
    neighborhoods,
)
from app.socket import sio, start_redis_bridge

logger = logging.getLogger(__name__)


async def _cleanup_stale_requested_trips() -> None:
    """End trips stuck in requested (e.g. dispatch never ran before a fix)."""
    from app.services import dispatch_service

    cutoff = datetime.now(timezone.utc) - timedelta(minutes=12)
    stale = 0
    async for doc in get_database()["trips"].find(
        {"status": "requested", "createdAt": {"$lt": cutoff}},
        projection={"_id": 1},
    ):
        trip_id = str(doc["_id"])
        await dispatch_service.fail_trip_no_drivers(trip_id)
        stale += 1
    if stale:
        logger.info("Cancelled %s stale requested trip(s)", stale)


class RequestIDMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
        request.state.request_id = request_id
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response


@asynccontextmanager
async def lifespan(app: FastAPI):
    setup_logging(
        level="INFO" if settings.is_production else "DEBUG",
        environment=settings.environment,
    )

    await connect_db()
    await connect_redis()
    bridge_task = asyncio.create_task(start_redis_bridge())
    try:
        await _cleanup_stale_requested_trips()
    except Exception:
        logger.exception("Stale trip cleanup failed")
    logger.info("Tashila API started (env=%s)", settings.environment)

    yield

    bridge_task.cancel()
    try:
        await bridge_task
    except asyncio.CancelledError:
        pass
    await close_redis()
    await close_db()
    logger.info("Tashila API shutdown complete")


def create_app() -> FastAPI:
    application = FastAPI(
        title="Tashila API",
        version="1.0.0",
        docs_url="/docs" if not settings.is_production else None,
        redoc_url=None,
        lifespan=lifespan,
    )

    application.add_middleware(RequestIDMiddleware)
    application.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    register_exception_handlers(application)

    application.include_router(auth.router)
    application.include_router(users.router)
    application.include_router(drivers.router)
    application.include_router(trips.router)
    application.include_router(pricing.router)
    application.include_router(neighborhoods.router)
    application.include_router(admin_users.router)
    application.include_router(admin_trips.router)
    application.include_router(admin_stats.router)
    application.include_router(admin_settings.router)
    application.include_router(uploads.router)

    # Serve local uploads only when Cloudinary is not configured.
    # With Cloudinary, all returned URLs are absolute (https://res.cloudinary.com/…)
    # so there is nothing to serve locally.
    if not settings.cloudinary_url:
        upload_root = Path(settings.upload_dir)
        upload_root.mkdir(parents=True, exist_ok=True)
        application.mount(
            "/uploads",
            StaticFiles(directory=str(upload_root)),
            name="uploads",
        )

    @application.get("/health", tags=["system"])
    async def health() -> dict[str, str]:
        return {
            "status": "ok",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "environment": settings.environment,
        }

    @application.get("/ready", tags=["system"])
    async def ready() -> JSONResponse:
        mongo_ok = await mongo_health_check()
        redis_ok = await redis_health_check()
        ok = mongo_ok and redis_ok
        body = {"mongo": mongo_ok, "redis": redis_ok, "ok": ok}
        if ok:
            return JSONResponse(status_code=status.HTTP_200_OK, content=body)
        return JSONResponse(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, content=body)

    return application


def create_asgi_app() -> socketio.ASGIApp:
    """Wrap the FastAPI app inside the Socket.IO ASGI app so that Socket.IO
    requests to ``/socket.io/…`` are handled by python-socketio and all other
    requests are forwarded to the FastAPI application unchanged."""
    fastapi_application = create_app()
    return socketio.ASGIApp(sio, other_asgi_app=fastapi_application)


app = create_asgi_app()
