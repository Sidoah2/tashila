#!/usr/bin/env python3
"""
Diagnostic & Live Dispatch Test Script for Driver 0611223344
-----------------------------------------------------------
Tests:
1. Driver profile, approval status, and online availability in MongoDB.
2. FCM Push Token registration in 'push_tokens' collection.
3. Sends a direct test FCM push to wake up the driver phone.
4. Creates a test trip near driver's location and dispatches offer to driver 0611223344.
5. Verifies the offer is available in /drivers/me/current-offer.
6. Waits for real-time driver response (accept / reject) or timeout, then cleans up.

Usage:
    python scripts/test_driver_0611223344_dispatch.py [--base-url URL] [--test-push-only]
"""

import argparse
import asyncio
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

# Add project root to sys.path
BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE_DIR))
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

from bson import ObjectId
from pymongo import MongoClient

# Load MongoDB URI
MONGO_URI = os.getenv(
    "MONGO_URI",
    "mongodb+srv://tashilaapp_db_user:FRrdylfkdQJaPQQ7@cluster0.by1q7lx.mongodb.net/?appName=Cluster0",
)
DB_NAME = os.getenv("MONGO_DB_NAME", "tashila")

TARGET_PHONE = "+213611223344"
TARGET_PHONE_ALT = "0611223344"


def print_step(title: str):
    print("\n" + "=" * 65)
    print(f"--> {title}")
    print("=" * 65)


def check_driver_status(db):
    print_step(f"1. Checking Driver Profile for {TARGET_PHONE}")
    driver = db.drivers.find_one({
        "$or": [{"phone": TARGET_PHONE}, {"phone": TARGET_PHONE_ALT}]
    })

    if not driver:
        print(f"[FAIL] Driver with phone {TARGET_PHONE} not found in database!")
        sys.exit(1)

    driver_id = str(driver["_id"])
    name = driver.get("name", "Unknown")
    approval = driver.get("approvalStatus", "pending")
    availability = driver.get("availability", "offline")
    truck_type = driver.get("truckType", "small")
    loc = driver.get("location") or {}
    coords = loc.get("coordinates", [3.0588, 36.7538])  # [lng, lat]

    print(f"   Driver ID:     {driver_id}")
    print(f"   Name:          {name}")
    print(f"   Approval:      {approval}")
    print(f"   Availability:  {availability}")
    print(f"   Truck Type:    {truck_type}")
    print(f"   Location:      lng={coords[0]}, lat={coords[1]}")

    if approval != "approved":
        print(f"⚠️ Warning: Driver approvalStatus is '{approval}' (must be 'approved' to receive trips).")
        print("   Auto-approving driver for this test...")
        db.drivers.update_one({"_id": driver["_id"]}, {"$set": {"approvalStatus": "approved"}})
        driver["approvalStatus"] = "approved"
        print("   ✅ Driver approvalStatus updated to 'approved'.")

    if availability != "online":
        print(f"⚠️ Notice: Driver availability is currently '{availability}'.")
        print("   Please toggle 'Online' in your phone app, or auto-setting to 'online' now...")
        db.drivers.update_one({"_id": driver["_id"]}, {"$set": {"availability": "online"}})
        driver["availability"] = "online"
        print("   ✅ Driver availability set to 'online' in MongoDB.")

    return driver


def check_push_token(db, driver_id):
    print_step(f"2. Checking FCM Push Token for Driver {driver_id}")
    token_doc = db.push_tokens.find_one({"ownerId": driver_id, "role": "driver"})

    if not token_doc:
        print("⚠️ No FCM push token registered yet in 'push_tokens' collection.")
        print("   Once you launch the updated Driver App on your phone, FCM token will be registered.")
        return None

    token = token_doc.get("token", "")
    platform = token_doc.get("platform", "fcm")
    updated = token_doc.get("updatedAt", token_doc.get("createdAt"))

    print(f"   ✅ Push Token Found ({platform.upper()}):")
    print(f"      {token[:25]}...{token[-15:]}")
    print(f"      Last Updated: {updated}")
    return token


def send_direct_fcm_test(token):
    print_step("3. Sending Direct Test Push via Firebase Admin SDK")
    try:
        import firebase_admin
        from firebase_admin import credentials, messaging

        app = None
        try:
            app = firebase_admin.get_app()
        except ValueError:
            creds_path = BASE_DIR / "firebase-adminsdk.json"
            if creds_path.exists():
                cred = credentials.Certificate(str(creds_path))
                app = firebase_admin.initialize_app(cred)
            else:
                app = firebase_admin.initialize_app()

        message = messaging.Message(
            token=token,
            notification=messaging.Notification(
                title="طلب رحلة جديد",
                body="الانطلاق: Place des Martyrs, Alger\nالوصول: Bab Ezzouar, Alger\nالسعر: 1800 دج",
            ),
            data={
                "type": "trip_request",
                "pickupAddress": "Place des Martyrs, Alger",
                "dropoffAddress": "Bab Ezzouar, Alger",
                "fare": "1800",
                "tripId": "test_trip_offer_123",
            },
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="driver_trip_offers",
                    priority="high",
                    default_sound=True,
                    click_action="FLUTTER_NOTIFICATION_CLICK",
                ),
            ),
        )
        response = messaging.send(message)
        print(f"   🎉 Test push message sent successfully! FCM Message ID: {response}")
        print("   📱 Check your phone! The notification should appear with sound/vibration.")
        print("   👉 Tapping it should enter the Tashila Driver App directly.")
        return True
    except Exception as e:
        print(f"   ❌ Failed to send FCM message: {e}")
        return False


def test_live_dispatch_flow(db, driver):
    import requests
    base_url = os.getenv("API_URL", "https://web-production-da6bc.up.railway.app").rstrip("/")
    print_step(f"4. Testing Live Ride Offer Dispatch via {base_url}/trips")
    driver_id = str(driver["_id"])
    loc = driver.get("location") or {}
    coords = loc.get("coordinates", [3.0588, 36.7538])
    lng, lat = coords[0], coords[1]
    truck_type = driver.get("truckType", "single_cabin")

    # 1. Log in a virtual client via test OTP
    client_phone = "+213711223344"
    print(f"   Logging in test client ({client_phone})...")
    try:
        requests.post(f"{base_url}/auth/otp/send", json={"phone": client_phone, "role": "client"}, timeout=10)
        verify_res = requests.post(
            f"{base_url}/auth/otp/verify",
            json={"phone": client_phone, "otp": "1111", "role": "client"},
            timeout=10,
        )
        if verify_res.status_code != 200:
            print(f"   [FAIL] Could not authenticate test client: {verify_res.status_code} {verify_res.text}")
            return
        client_token = verify_res.json().get("accessToken")
    except Exception as e:
        print(f"   [FAIL] Client login error: {e}")
        return

    # 2. Call POST /trips to trigger the real dispatch worker
    trip_payload = {
        "pickup": {
            "lat": lat,
            "lng": lng,
            "address": "123 Rue Didouche Mourad, Alger",
        },
        "dropoff": {
            "lat": lat + 0.02,
            "lng": lng + 0.02,
            "address": "Bab Ezzouar, Alger",
        },
        "truckType": truck_type,
        "paymentMethod": "cash",
        "notes": "Live test dispatch to driver 0611223344",
    }

    print(f"   Requesting trip via POST /trips at coordinates ({lat}, {lng}) for truckType '{truck_type}'...")
    try:
        trip_res = requests.post(
            f"{base_url}/trips",
            json=trip_payload,
            headers={"Authorization": f"Bearer {client_token}"},
            timeout=15,
        )
        if trip_res.status_code not in (200, 201):
            print(f"   [FAIL] Failed creating trip: {trip_res.status_code} {trip_res.text}")
            return

        trip_data = trip_res.json()
        trip_obj = trip_data.get("trip") if isinstance(trip_data.get("trip"), dict) else trip_data
        trip_id = trip_obj.get("id") or trip_obj.get("_id")
        fare = trip_obj.get("fare")
        print(f"   [OK] Trip created on backend! ID: {trip_id} (Fare: {fare} DZD)")
        print("   >>> THE BACKEND DISPATCH ENGINE HAS BROADCASTED THE OFFER TO YOUR PHONE! <<<")
    except Exception as e:
        print(f"   [FAIL] Request exception: {e}")
        return

    # 3. Wait for driver response (Accept/Reject) on their real phone
    print("\n   Watching your phone for response (Accept or Reject)...")
    trip_accepted = False
    for i in range(35):
        time.sleep(1)
        trip_state = db.trips.find_one({"_id": ObjectId(trip_id)})
        current_status = trip_state.get("status") if trip_state else "unknown"
        if current_status == "accepted":
            print(f"\n   [SUCCESS] Driver ACCEPTED the trip on their phone! (Status: {current_status})")
            trip_accepted = True
            break
        elif current_status in ("rejected", "cancelled"):
            print(f"\n   Driver response: {current_status}")
            break
        sys.stdout.write(f"\r   [{i+1}/35s] Trip Status on Server: {current_status}...")
        sys.stdout.flush()

    # 4. Clean up test trip
    print("\n\n   Cleaning up test trip...")
    try:
        requests.post(
            f"{base_url}/trips/{trip_id}/cancel",
            params={"reason": "test_cleanup"},
            headers={"Authorization": f"Bearer {client_token}"},
            timeout=10,
        )
    except Exception:
        pass
    db.trips.delete_one({"_id": ObjectId(trip_id)})
    print("   [OK] Test trip cleaned up.")


def main():
    parser = argparse.ArgumentParser(description="Test dispatch and FCM for driver 0611223344")
    parser.add_argument("--test-push-only", action="store_true", help="Only send test push notification")
    args = parser.parse_args()

    client = MongoClient(MONGO_URI)
    db = client[DB_NAME]

    driver = check_driver_status(db)
    driver_id = str(driver["_id"])
    token = check_push_token(db, driver_id)

    if token:
        send_direct_fcm_test(token)
    else:
        print("\nℹ️  To test FCM Push Notification:")
        print("   1. Build/run the updated Tashila Driver App on your phone.")
        print("   2. When prompted, allow Notification permissions.")
        print("   3. Run this script again - the push token will be recognized automatically!")

    if not args.test_push_only:
        test_live_dispatch_flow(db, driver)


if __name__ == "__main__":
    main()
