import asyncio
import logging
from datetime import datetime, timedelta, timezone
from typing import Any

from bson import ObjectId

from app.core.database import get_database
from app.services.dispatch_service import _driver_ids_with_active_trips
from app.services.driver_service import DRIVERS_COLLECTION, set_availability
from app.services.notification_service import push_driver_inactivity_check

logger = logging.getLogger(__name__)

DEFAULT_INACTIVITY_MINUTES = 15
MAX_UNANSWERED_ALERTS = 4


async def check_and_notify_inactive_drivers(
    inactivity_threshold_minutes: int = DEFAULT_INACTIVITY_MINUTES,
) -> dict[str, Any]:
    """
    Finds drivers that have been online without app activity for >= 15 minutes,
    and sends them an interactive push notification asking if they are still available.
    """
    now = datetime.now(timezone.utc)
    inactivity_cutoff = now - timedelta(minutes=inactivity_threshold_minutes)

    busy_drivers = await _driver_ids_with_active_trips()

    db = get_database()
    query: dict[str, Any] = {
        "availability": "online",
        "approvalStatus": "approved",
        "$or": [
            {"lastActiveAt": {"$lte": inactivity_cutoff}},
            {"lastActiveAt": None, "updatedAt": {"$lte": inactivity_cutoff}},
            {"lastActiveAt": {"$exists": False}, "updatedAt": {"$lte": inactivity_cutoff}},
        ],
    }

    cursor = db[DRIVERS_COLLECTION].find(query)
    notified_count = 0
    auto_offline_count = 0

    async for driver in cursor:
        driver_id = str(driver["_id"])
        if driver_id in busy_drivers:
            continue

        last_alert = driver.get("lastInactivityAlertAt")
        if last_alert:
            if last_alert.tzinfo is None:
                last_alert = last_alert.replace(tzinfo=timezone.utc)
            if (now - last_alert) < timedelta(minutes=inactivity_threshold_minutes):
                continue

        unanswered = int(driver.get("unansweredInactivityAlerts", 0))

        if unanswered >= MAX_UNANSWERED_ALERTS:
            logger.info(
                "Driver %s had %d unanswered inactivity alerts. Auto-setting to offline.",
                driver_id,
                unanswered,
            )
            await set_availability(driver_id, "offline")
            auto_offline_count += 1
            continue

        sent = await push_driver_inactivity_check(driver_id)
        logger.info(
            "Sent inactivity check notification to driver %s (success=%s, unanswered=%d)",
            driver_id,
            sent,
            unanswered,
        )

        await db[DRIVERS_COLLECTION].update_one(
            {"_id": ObjectId(driver_id)},
            {
                "$set": {"lastInactivityAlertAt": now},
                "$inc": {"unansweredInactivityAlerts": 1},
            },
        )
        notified_count += 1

    return {
        "status": "ok",
        "notified": notified_count,
        "autoOffline": auto_offline_count,
        "timestamp": now.isoformat(),
    }


async def start_inactivity_monitor(poll_interval_seconds: int = 60) -> None:
    """
    Background worker loop that periodically checks for inactive drivers.
    """
    logger.info("Driver inactivity monitor loop started (check interval: %ds)", poll_interval_seconds)
    while True:
        try:
            await check_and_notify_inactive_drivers()
        except asyncio.CancelledError:
            logger.info("Driver inactivity monitor stopped")
            break
        except Exception:
            logger.exception("Error in driver inactivity monitor loop")

        try:
            await asyncio.sleep(poll_interval_seconds)
        except asyncio.CancelledError:
            break
