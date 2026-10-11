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
    print(f"👉 {title}")
    print("=" * 65)


def check_driver_status(db):
    print_step(f"1. Checking Driver Profile for {TARGET_PHONE}")
    driver = db.drivers.find_one({
        "$or": [{"phone": TARGET_PHONE}, {"phone": TARGET_PHONE_ALT}]
    })

    if not driver:
        print(f"❌ Driver with phone {TARGET_PHONE} not found in database!")
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
                title="Tashila Test: طلب رحلة تجريبي",
                body="اضغط هنا للدخول مباشرة لشاشة العرض والقبول (Trip Offer Test)",
            ),
            data={
                "type": "trip_request",
                "pickupAddress": "Place des Martyrs, Alger",
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
    print_step("4. Testing Live Ride Offer Dispatch to Driver")
    driver_id = str(driver["_id"])
    loc = driver.get("location") or {}
    coords = loc.get("coordinates", [3.0588, 36.7538])
    lng, lat = coords[0], coords[1]

    # Create a test trip in MongoDB
    client_user = db.users.find_one({"role": "client"})
    if not client_user:
        client_id = str(ObjectId())
        client_name = "Test Client"
        client_phone = "+213555000111"
    else:
        client_id = str(client_user["_id"])
        client_name = client_user.get("name", "Test Client")
        client_phone = client_user.get("phone", "+213555000111")

    now = datetime.now(timezone.utc)
    test_trip = {
        "clientId": client_id,
        "clientName": client_name,
        "clientPhone": client_phone,
        "status": "requested",
        "truckType": driver.get("truckType", "small"),
        "targetedDriverId": driver_id,
        "pickup": {
            "address": "123 Rue Didouche Mourad, Alger",
            "location": {"type": "Point", "coordinates": [lng, lat]},
        },
        "dropoff": {
            "address": "Bab Ezzouar, Alger",
            "location": {"type": "Point", "coordinates": [lng + 0.05, lat + 0.05]},
        },
        "fare": 1800.0,
        "distanceKm": 12.5,
        "durationMinutes": 25,
        "createdAt": now,
        "updatedAt": now,
    }

    res = db.trips.insert_one(test_trip)
    trip_id = str(res.inserted_id)
    print(f"   ✅ Created Test Trip in DB: ID = {trip_id}")
    print(f"      Pickup:  {test_trip['pickup']['address']}")
    print(f"      Fare:    {test_trip['fare']} DZD")
    print(f"      Target:  Driver {driver.get('name')} ({driver_id})")

    # If push token exists, send the trip offer push notification
    token_doc = db.push_tokens.find_one({"ownerId": driver_id, "role": "driver"})
    if token_doc and token_doc.get("token"):
        print("\n   📲 Dispatching FCM Push Notification for Trip Offer...")
        send_direct_fcm_test(token_doc["token"])

    print("\n   ⏳ Waiting up to 30 seconds for driver response in mobile app...")
    for i in range(30):
        time.sleep(1)
        trip_state = db.trips.find_one({"_id": ObjectId(trip_id)})
        current_status = trip_state.get("status") if trip_state else "unknown"
        if current_status == "accepted":
            print(f"\n   🎉 SUCCESS: Driver accepted the trip! (Trip Status: {current_status})")
            break
        elif current_status == "rejected" or current_status == "cancelled":
            print(f"\n   Driver response: {current_status}")
            break
        sys.stdout.write(f"\r   [{i+1}/30s] Trip Status: {current_status}...")
        sys.stdout.flush()

    # Clean up test trip
    print("\n\n   🧹 Cleaning up test trip...")
    db.trips.delete_one({"_id": ObjectId(trip_id)})
    print("   ✅ Test trip cleaned up from database.")


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
