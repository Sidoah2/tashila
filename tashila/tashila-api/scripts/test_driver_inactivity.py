#!/usr/bin/env python3
"""
Interactive test script for driver inactivity notifications.
Designed for live device testing with driver 0611223344 (or any phone).

Usage:
    python scripts/test_driver_inactivity.py
    or
    python scripts/test_driver_inactivity.py --phone 0611223344
    or
    python scripts/test_driver_inactivity.py --watch
"""

import argparse
import asyncio
import os
import sys
import time

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

# Ensure app package is importable
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from bson import ObjectId
from app.core.database import connect_db, close_db, get_database
from app.services.driver_service import DRIVERS_COLLECTION
from app.services.notification_service import push_driver_inactivity_check


async def find_driver(db, phone: str):
    clean_phone = phone.strip().replace(" ", "").replace("-", "")
    # Try exact match, with +212, with 0 prefix, or regex
    candidates = [
        clean_phone,
        f"+212{clean_phone.lstrip('0')}",
        f"0{clean_phone.lstrip('+212')}",
        clean_phone.lstrip("+"),
    ]
    for p in candidates:
        d = await db[DRIVERS_COLLECTION].find_one({"phone": p})
        if d:
            return d

    # Fallback regex search
    suffix = clean_phone[-8:] if len(clean_phone) >= 8 else clean_phone
    d = await db[DRIVERS_COLLECTION].find_one({"phone": {"$regex": suffix}})
    return d


async def monitor_driver(db, driver_id: str, timeout_sec: int = 60):
    print(f"\n[LIVE MONITOR] Watching driver {driver_id} status for {timeout_sec}s...")
    print("Tap an action button on your phone notification to see the update in real-time!\n")

    start_time = time.time()
    last_avail = None
    last_active = None

    while time.time() - start_time < timeout_sec:
        d = await db[DRIVERS_COLLECTION].find_one({"_id": ObjectId(driver_id)})
        if not d:
            break

        curr_avail = d.get("availability")
        curr_active = d.get("lastActiveAt")

        if last_avail is None:
            last_avail = curr_avail
            last_active = curr_active
            print(f" Initial State -> Availability: '{curr_avail}' | LastActiveAt: {curr_active}")
        else:
            if curr_avail != last_avail:
                print(f"\n>>> [STATUS CHANGE DETECTED] <<<")
                print(f"    Availability changed: '{last_avail}' -> '{curr_avail}'")
                if curr_avail == "offline":
                    print("    SUCCESS: Driver tapped 'تحويل إلى غير متصل' (Switched to OFFLINE)!")
                    return
                last_avail = curr_avail

            if curr_active != last_active:
                print(f" [*] Activity heartbeat: {curr_active}")
                last_active = curr_active

        await asyncio.sleep(2)

    print("\n[MONITOR TIMEOUT] No button was tapped within 60s.")


async def main():
    parser = argparse.ArgumentParser(description="Test driver inactivity notification")
    parser.add_argument("--phone", default="0611223344", help="Driver phone number (default: 0611223344)")
    parser.add_argument("--watch", action="store_true", default=True, help="Watch status in real-time after sending push")
    parser.add_argument("--nowatch", dest="watch", action="store_false", help="Don't watch status, just send push")
    args = parser.parse_args()

    from motor.motor_asyncio import AsyncIOMotorClient
    from app.core.config import settings
    import app.core.database as db_mod

    client = AsyncIOMotorClient(settings.mongo_uri, serverSelectionTimeoutMS=10000)
    db = client[settings.mongo_db_name]
    db_mod._client = client
    db_mod._db = db

    try:
        print("=" * 65)
        print(" Tashila Inactivity Notification Tester")
        print("=" * 65)

        driver = await find_driver(db, args.phone)
        if not driver:
            print(f"[-] Driver with phone '{args.phone}' not found in database.")
            print("\nRecent drivers in database:")
            cursor = db[DRIVERS_COLLECTION].find().sort("_id", -1).limit(5)
            async for d in cursor:
                print(f"  - Name: {d.get('name', 'N/A')} | Phone: {d.get('phone')} | Availability: {d.get('availability')}")
            print("\nPlease ensure you have registered/logged in with phone 0611223344 in the app.")
            return

        driver_id = str(driver["_id"])
        phone = driver.get("phone")
        name = driver.get("name", "Driver")
        avail = driver.get("availability", "offline")
        last_active = driver.get("lastActiveAt")

        print(f"[+] Found Driver:")
        print(f"    Name:         {name}")
        print(f"    Phone:        {phone}")
        print(f"    ID:           {driver_id}")
        print(f"    Availability: {avail}")
        print(f"    Last Active:  {last_active}")

        # Check push token
        token_doc = await db["push_tokens"].find_one({"ownerId": driver_id, "role": "driver"})
        if not token_doc:
            print(f"\n[!] WARNING: Driver {phone} has no push token in 'push_tokens' collection yet.")
            print("    Please open the Driver App on your phone, log in, and grant Notification permissions.")
            print("    The app registers its FCM push token immediately upon login.")
            return

        print(f"[+] Push Token:   {token_doc.get('token')[:24]}... (Platform: {token_doc.get('platform')})")

        print("\n==> Sending interactive inactivity notification (Category: INACTIVITY_CHECK)...")
        print("    Title:   هل ما زلت متاحاً للعمل؟")
        print("    Actions: [أنا متاح]  |  [تحويل إلى غير متصل]")

        success = await push_driver_inactivity_check(driver_id)
        if success:
            print("[+] Notification sent successfully via FCM/APNs!")
            if args.watch:
                await monitor_driver(db, driver_id)
        else:
            print("[-] Failed to send notification. Please check Firebase credentials and token.")

    finally:
        await close_db()


if __name__ == "__main__":
    asyncio.run(main())
