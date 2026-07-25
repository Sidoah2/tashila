"""HTTP route modules."""

from app.routers import (
    admin_stats,
    admin_trips,
    admin_users,
    auth,
    drivers,
    pricing,
    trips,
    uploads,
    users,
)

__all__ = [
    "admin_stats",
    "admin_trips",
    "admin_users",
    "auth",
    "drivers",
    "pricing",
    "trips",
    "uploads",
    "users",
]
