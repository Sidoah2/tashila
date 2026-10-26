#!/usr/bin/env python3
"""
Test script to send an inactivity notification directly to a driver,
allowing end-to-end verification on real devices (iOS / Android).

Usage:
    python scripts/test_inactivity_push.py --phone +213555123456
    or
    python scripts/test_inactivity_push.py --driver-id 64a...
"""

import argparse
import asyncio
import os
import sys

# Ensure app package is importable
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from bson import ObjectId
from app.core.database import connect_db, close_db, get_database
from app.services.driver_service import DRIVERS_COLLECTION
from app.services.notification_service import push_driver_inactivity_check


async def main():
    parser = argparse.ArgumentParser(description="Test driver inactivity notification")
    parser.add_argument("--phone", help="Driver phone number (e.g. +213555123456)")
    parser.add_argument("--driver-id", help="Driver MongoDB ObjectId string")
    parser.add_argument("--check-worker", action="store_true", help="Run the full inactivity check worker")
    args = parser.parse_args()

    await connect_db()
    db = get_database()

    try:
        driver = None
        if args.driver_id:
            driver = await db[DRIVERS_COLLECTION].find_one({"_id": ObjectId(args.driver_id)})
        elif args.phone:
            driver = await db[DRIVERS_COLLECTION].find_one({"phone": args.phone})
        elif not args.check_worker:
            # Pick any online driver with a push token
            cursor = db["push_tokens"].find({"role": "driver"}).limit(1)
            token_doc = await cursor.to_list(1)
            if token_doc:
                driver_id = token_doc[0]["ownerId"]
                driver = await db[DRIVERS_COLLECTION].find_one({"_id": ObjectId(driver_id)})

        if args.check_worker:
            print("==> Running check_and_notify_inactive_drivers()...")
            from app.services.inactivity_service import check_and_notify_inactive_drivers
            res = await check_and_notify_inactive_drivers(inactivity_threshold_minutes=0)
            print("Result:", res)
            return

        if not driver:
            print("ERROR: Driver not found. Please provide --phone or --driver-id.")
            return

        driver_id = str(driver["_id"])
        print(f"==> Target Driver: {driver.get('name', 'Driver')} (ID: {driver_id}, Phone: {driver.get('phone')})")
        print(f"    Current availability: {driver.get('availability')}")

        # Check push token
        token_doc = await db["push_tokens"].find_one({"ownerId": driver_id, "role": "driver"})
        if not token_doc:
            print(f"WARNING: Driver {driver_id} has no registered push token in DB! Notification may fail.")
        else:
            print(f"    Push token found (platform: {token_doc.get('platform')})")

        print("==> Sending interactive inactivity notification (Category: INACTIVITY_CHECK)...")
        success = await push_driver_inactivity_check(driver_id)
        if success:
            print("[SUCCESS] Notification dispatched successfully!")
            print("Check your mobile device (iOS / Android) for the notification:")
            print(" - Action 1: 'أنا متاح'")
            print(" - Action 2: 'تحويل إلى غير متصل'")
        else:
            print("[FAILED] Failed to send push notification. Check Firebase logs and push token.")

    finally:
        await close_db()


if __name__ == "__main__":
    asyncio.run(main())
