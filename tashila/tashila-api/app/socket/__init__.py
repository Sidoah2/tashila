import logging

import socketio

logger = logging.getLogger(__name__)

sio = socketio.AsyncServer(
    async_mode="asgi",
    cors_allowed_origins="*",
    logger=False,
    engineio_logger=False,
    ping_timeout=20,
    ping_interval=25,
)

# Register event handlers
from app.socket import client_handlers as _client_handlers  # noqa: E402
from app.socket import driver_handlers as _driver_handlers  # noqa: E402
from app.socket import manager as _manager  # noqa: E402, F401
from app.socket.redis_bridge import start_redis_bridge  # noqa: E402

_client_handlers.register_client_handlers(sio)
_driver_handlers.register_driver_handlers(sio)

__all__ = [
    "sio",
    "start_redis_bridge",
    "emit_to_driver",
    "emit_to_trip_room",
    "notify_trip_status_changed",
    "notify_driver_assigned",
    "notify_no_drivers_found",
    "notify_fare_updated",
]

emit_to_driver = _manager.emit_to_driver
emit_to_trip_room = _manager.emit_to_trip_room
notify_trip_status_changed = _client_handlers.notify_trip_status_changed
notify_driver_assigned = _client_handlers.notify_driver_assigned
notify_no_drivers_found = _client_handlers.notify_no_drivers_found
notify_fare_updated = _client_handlers.notify_fare_updated
