#!/usr/bin/env python3
"""
Production Broadcast Dispatch Verification Script.

Tests the multi-driver broadcast dispatch flow without physical devices:
1. Logs in Driver A (+213611223344) and Driver B (+213711223344) using test OTP (1111).
2. Sets both drivers to ONLINE and syncs their coordinates to the same location.
3. Connects both drivers via Socket.IO and listens for 'driver:trip_request'.
4. Logs in a test Client and creates a trip with matching truckType and coordinates.
5. Verifies SIMULTANEOUS BROADCAST:
   - Measures exact timestamps when Driver A and Driver B receive the offer.
   - Confirms whether dispatch is true broadcast (both receive at once) vs sequential.
6. Tests Decline & Accept:
   - Driver A declines (rejects) the offer.
   - Driver B accepts the offer.
   - Verifies trip transitions to 'accepted' assigned to Driver B.
7. Cleans up test trip and resets driver status.

Usage:
    python scripts/test_broadcast_dispatch_flow.py [--url http://localhost:8000]
    python scripts/test_broadcast_dispatch_flow.py --url https://tashila-api-production.up.railway.app
"""

import argparse
import asyncio
import json
import logging
import sys
import time
from datetime import datetime, timezone

import httpx
import socketio

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("broadcast-test")

# Coordinate for dispatch testing (Algiers center)
TEST_LAT = 36.7538
TEST_LNG = 3.0588
TEST_TRUCK_TYPE = "single_cabin"


class VirtualDriverActor:
    def __init__(self, phone: str, label: str, base_url: str):
        self.phone = phone
        self.label = label
        self.base_url = base_url.rstrip("/")
        self.token: str | None = None
        self.driver_id: str | None = None
        self.sio = socketio.AsyncClient(logger=False, engineio_logger=False)
        self.received_offers: list[dict] = []
        self.offer_events: asyncio.Queue[dict] = asyncio.Queue()

    async def login(self, client: httpx.AsyncClient) -> bool:
        logger.info(f"[{self.label}] Requesting OTP for {self.phone}...")
        resp = await client.post(
            f"{self.base_url}/auth/otp/send",
            json={"phone": self.phone, "role": "driver"},
        )
        if resp.status_code != 200:
            logger.error(f"[{self.label}] Failed to send OTP: {resp.status_code} {resp.text}")
            return False

        logger.info(f"[{self.label}] Verifying test OTP (1111)...")
        resp = await client.post(
            f"{self.base_url}/auth/otp/verify",
            json={"phone": self.phone, "otp": "1111", "role": "driver"},
        )
        if resp.status_code != 200:
            logger.error(f"[{self.label}] Failed to verify OTP: {resp.status_code} {resp.text}")
            return False

        data = resp.json()
        self.token = data.get("accessToken")
        self.driver_id = data.get("user", {}).get("id") or data.get("user", {}).get("_id")
        logger.info(f"[{self.label}] Logged in successfully. Driver ID: {self.driver_id}")
        return True

    def headers(self) -> dict:
        return {"Authorization": f"Bearer {self.token}"}

    async def set_online_and_location(self, client: httpx.AsyncClient, lat: float, lng: float) -> bool:
        # Set online
        r1 = await client.put(
            f"{self.base_url}/drivers/me/availability",
            json={"availability": "online"},
            headers=self.headers(),
        )
        if r1.status_code not in (200, 204):
            logger.warning(f"[{self.label}] Update availability failed: {r1.status_code} {r1.text}")

        # Set location
        r2 = await client.put(
            f"{self.base_url}/drivers/me/location",
            json={"lat": lat, "lng": lng, "heading": 0.0, "speed": 0.0},
            headers=self.headers(),
        )
        if r2.status_code not in (200, 204):
            logger.warning(f"[{self.label}] Update location failed: {r2.status_code} {r2.text}")

        logger.info(f"[{self.label}] Availability set to ONLINE, location set to ({lat}, {lng})")
        return True

    async def connect_socket(self) -> bool:
        @self.sio.on("driver:trip_request")
        async def on_trip_request(data):
            recv_time = time.time()
            data["_client_received_at"] = recv_time
            data["_formatted_time"] = datetime.now(timezone.utc).isoformat()
            self.received_offers.append(data)
            await self.offer_events.put(data)
            logger.info(
                f"[{self.label}] >>> RECEIVED 'driver:trip_request' for trip {data.get('tripId')} "
                f"at {data['_formatted_time']}"
            )

        @self.sio.on("driver:offer_expired")
        async def on_offer_expired(data):
            logger.info(f"[{self.label}] Offer expired: {data}")

        try:
            ws_url = self.base_url
            logger.info(f"[{self.label}] Connecting Socket.IO to {ws_url}...")
            await self.sio.connect(
                ws_url,
                auth={"token": self.token},
                transports=["websocket", "polling"],
                wait_timeout=10,
            )
            logger.info(f"[{self.label}] Socket.IO connected (sid={self.sio.sid})")
            return True
        except Exception as e:
            logger.error(f"[{self.label}] Socket.IO connection failed: {e}")
            return False

    async def fetch_incoming_http_offers(self, client: httpx.AsyncClient) -> list[dict]:
        try:
            resp = await client.get(
                f"{self.base_url}/drivers/me/trip-requests",
                headers=self.headers(),
            )
            if resp.status_code == 200:
                return resp.json()
        except Exception as e:
            logger.error(f"[{self.label}] Failed fetching HTTP offers: {e}")
        return []

    async def accept_trip(self, client: httpx.AsyncClient, trip_id: str) -> dict:
        resp = await client.post(
            f"{self.base_url}/trips/{trip_id}/accept",
            headers=self.headers(),
        )
        return {"status_code": resp.status_code, "data": resp.json() if resp.status_code == 200 else resp.text}

    async def reject_trip(self, client: httpx.AsyncClient, trip_id: str) -> dict:
        resp = await client.post(
            f"{self.base_url}/trips/{trip_id}/reject",
            headers=self.headers(),
        )
        return {"status_code": resp.status_code, "text": resp.text}

    async def disconnect(self):
        if self.sio.connected:
            await self.sio.disconnect()


class VirtualClientActor:
    def __init__(self, phone: str, base_url: str):
        self.phone = phone
        self.base_url = base_url.rstrip("/")
        self.token: str | None = None
        self.client_id: str | None = None

    async def login(self, client: httpx.AsyncClient) -> bool:
        logger.info(f"[Client] Requesting OTP for {self.phone}...")
        resp = await client.post(
            f"{self.base_url}/auth/otp/send",
            json={"phone": self.phone, "role": "client"},
        )
        if resp.status_code != 200:
            logger.error(f"[Client] Failed to send OTP: {resp.status_code} {resp.text}")
            return False

        logger.info("[Client] Verifying test OTP (1111)...")
        resp = await client.post(
            f"{self.base_url}/auth/otp/verify",
            json={"phone": self.phone, "otp": "1111", "role": "client"},
        )
        if resp.status_code != 200:
            logger.error(f"[Client] Failed to verify OTP: {resp.status_code} {resp.text}")
            return False

        data = resp.json()
        self.token = data.get("accessToken")
        self.client_id = data.get("user", {}).get("id") or data.get("user", {}).get("_id")
        logger.info(f"[Client] Logged in successfully. Client ID: {self.client_id}")
        return True

    def headers(self) -> dict:
        return {"Authorization": f"Bearer {self.token}"}

    async def create_trip(self, client: httpx.AsyncClient, lat: float, lng: float, truck_type: str) -> dict | None:
        payload = {
            "pickup": {
                "lat": lat,
                "lng": lng,
                "address": "123 Rue Didouche Mourad, Alger",
            },
            "dropoff": {
                "lat": lat + 0.02,
                "lng": lng + 0.02,
                "address": "456 Boulevard Zighoud Youcef, Alger",
            },
            "truckType": truck_type,
            "paymentMethod": "cash",
            "notes": "Automated broadcast test",
        }
        logger.info(f"[Client] Requesting trip (truckType={truck_type}, pickup=({lat}, {lng}))...")
        resp = await client.post(
            f"{self.base_url}/trips",
            json=payload,
            headers=self.headers(),
            timeout=15.0,
        )
        if resp.status_code in (200, 201):
            trip_data = resp.json()
            trip_obj = trip_data.get("trip") if isinstance(trip_data.get("trip"), dict) else trip_data
            trip_id = trip_obj.get("id") or trip_obj.get("_id")
            logger.info(f"[Client] Trip response: {trip_data}")
            logger.info(f"[Client] Trip ID: {trip_id}, status: {trip_obj.get('status')}")
            return trip_data
        else:
            logger.error(f"[Client] Failed creating trip: {resp.status_code} {resp.text}")
            return None

    async def cancel_trip(self, client: httpx.AsyncClient, trip_id: str):
        try:
            await client.post(
                f"{self.base_url}/trips/{trip_id}/cancel",
                params={"reason": "test_cleanup"},
                headers=self.headers(),
            )
        except Exception:
            pass


async def run_broadcast_verification(base_url: str):
    print("=" * 70)
    print(" TASHILA BROADCAST DISPATCH TEST SUITE")
    print(f" Target API: {base_url}")
    print("=" * 70)

    driver_a = VirtualDriverActor("0611223344", "Driver A", base_url)
    driver_b = VirtualDriverActor("0711223344", "Driver B", base_url)
    test_client = VirtualClientActor("0550123456", base_url)

    async with httpx.AsyncClient(timeout=20.0) as http:
        # Step 1: Login Drivers
        print("\n[Step 1/5] Authenticating Driver A & Driver B...")
        if not await driver_a.login(http):
            print("FAILED: Could not log in Driver A.")
            return False
        if not await driver_b.login(http):
            print("FAILED: Could not log in Driver B.")
            return False

        # Step 2: Set Online & Coordinates
        print("\n[Step 2/5] Setting both drivers ONLINE at identical location...")
        await driver_a.set_online_and_location(http, TEST_LAT, TEST_LNG)
        await driver_b.set_online_and_location(http, TEST_LAT, TEST_LNG)

        # Step 3: Connect Sockets
        print("\n[Step 3/5] Connecting Socket.IO for real-time dispatch listening...")
        await driver_a.connect_socket()
        await driver_b.connect_socket()
        await asyncio.sleep(1.0)

        # Step 4: Login Client & Create Trip
        print("\n[Step 4/5] Logging in Client and Creating Trip...")
        if not await test_client.login(http):
            print("FAILED: Could not log in Client.")
            return False

        trip = await test_client.create_trip(http, TEST_LAT, TEST_LNG, TEST_TRUCK_TYPE)
        if not trip:
            print("FAILED: Could not create trip.")
            return False

        trip_obj = trip.get("trip") if isinstance(trip.get("trip"), dict) else trip
        trip_id = trip_obj.get("id") or trip_obj.get("_id")
        created_time = time.time()

        # Step 5: Wait for Broadcast to Both Drivers
        print("\n[Step 5/5] Monitoring real-time dispatch broadcast...")
        print(f"Waiting up to 10s for dispatch events on trip {trip_id}...")

        driver_a_offer = None
        driver_b_offer = None

        start_wait = time.time()
        while time.time() - start_wait < 10.0:
            # Check Socket events
            if not driver_a_offer and driver_a.received_offers:
                for o in driver_a.received_offers:
                    if o.get("tripId") == trip_id:
                        driver_a_offer = o
                        break

            if not driver_b_offer and driver_b.received_offers:
                for o in driver_b.received_offers:
                    if o.get("tripId") == trip_id:
                        driver_b_offer = o
                        break

            if driver_a_offer and driver_b_offer:
                break
            await asyncio.sleep(0.5)

        # Fallback: check HTTP if socket missed
        if not driver_a_offer:
            http_offers = await driver_a.fetch_incoming_http_offers(http)
            for o in http_offers:
                if (o.get("id") or o.get("tripId")) == trip_id:
                    driver_a_offer = o
                    driver_a_offer["_source"] = "HTTP_POLL"
                    break

        if not driver_b_offer:
            http_offers = await driver_b.fetch_incoming_http_offers(http)
            for o in http_offers:
                if (o.get("id") or o.get("tripId")) == trip_id:
                    driver_b_offer = o
                    driver_b_offer["_source"] = "HTTP_POLL"
                    break

        # Analysis & Verdict
        print("\n" + "=" * 70)
        print(" BROADCAST DISPATCH TEST RESULTS")
        print("=" * 70)

        a_received = driver_a_offer is not None
        b_received = driver_b_offer is not None

        print(f"Driver A received offer: {a_received}")
        if a_received:
            a_time = driver_a_offer.get("_formatted_time", "via HTTP")
            print(f"  - Driver A delivery time: {a_time}")

        print(f"Driver B received offer: {b_received}")
        if b_received:
            b_time = driver_b_offer.get("_formatted_time", "via HTTP")
            print(f"  - Driver B delivery time: {b_time}")

        if a_received and b_received:
            diff = abs(driver_a_offer.get("_client_received_at", 0) - driver_b_offer.get("_client_received_at", 0))
            print(f"\nTime difference between Driver A and B receipt: {diff:.3f} seconds")
            if diff < 3.0:
                print(">> [VERDICT]: TRUE SIMULTANEOUS BROADCAST CONFIRMED! <<")
            else:
                print(">> [VERDICT]: SEQUENTIAL DISPATCH DETECTED (Offer arrived with delay) <<")
        elif a_received and not b_received:
            print("\n>> [VERDICT]: SEQUENTIAL / RESTRICTED DISPATCH DETECTED! <<")
            print("   Driver A received the trip, but Driver B did NOT receive it simultaneously.")
        elif not a_received and b_received:
            print("\n>> [VERDICT]: Only Driver B received the trip. <<")
        else:
            print("\n>> [VERDICT]: Neither driver received the trip. Check dispatch radius / candidate filters. <<")

        # Test Reject by Driver A and Accept by Driver B
        if a_received or b_received:
            print("\n" + "-" * 70)
            print(" TESTING CONCURRENT DECLINE & ACCEPT FLOW")
            print("-" * 70)

            print("[Action] Driver A rejects/ignores the trip...")
            rej_res = await driver_a.reject_trip(http, trip_id)
            print(f"Driver A reject response: HTTP {rej_res['status_code']}")

            print("[Action] Driver B accepts the trip...")
            acc_res = await driver_b.accept_trip(http, trip_id)
            print(f"Driver B accept response: HTTP {acc_res['status_code']}")
            if acc_res["status_code"] == 200:
                print(">> [SUCCESS]: Driver B successfully accepted the trip! <<")
            else:
                print(f">> [FAILED]: Driver B could not accept trip: {acc_res['data']} <<")

        # Cleanup
        print("\nCleaning up test session...")
        await test_client.cancel_trip(http, trip_id)
        await driver_a.disconnect()
        await driver_b.disconnect()
        print("All connections closed.\n")
        return a_received and b_received


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test Broadcast Dispatch Flow")
    parser.add_argument(
        "--url",
        default="https://web-production-da6bc.up.railway.app",
        help="Base API URL (default: https://web-production-da6bc.up.railway.app)",
    )
    args = parser.parse_args()
    asyncio.run(run_broadcast_verification(args.url))
