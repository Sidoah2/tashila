"""VirtualDriver: registers, gets approved, connects via Socket.IO, handles trip offers."""
from __future__ import annotations

import asyncio
import logging
import random
import time
from datetime import datetime, timezone

import httpx
import socketio

from scripts.simulate import config, reporter
from scripts.simulate.actors.auth import register_driver

logger = logging.getLogger("sim.driver")

STATUS_CHAIN = ["headingToPickup", "inProgress", "awaitingCash", "completed"]


def _parse_expires_at(offer: dict) -> float | None:
    raw = offer.get("expiresAt")
    if not raw:
        return None
    try:
        dt = datetime.fromisoformat(str(raw).replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.timestamp()
    except ValueError:
        return None


class VirtualDriver:
    def __init__(self, idx: int, stop_event: asyncio.Event) -> None:
        self.idx = idx
        self.label = f"driver-{idx}"
        self.stop_event = stop_event
        self.token = ""
        self.user_id = ""
        self.truck_type = ""
        self._pending_offer: asyncio.Queue[dict] = asyncio.Queue()
        self._active_trip_id: str | None = None

    async def _register(self, http: httpx.AsyncClient) -> bool:
        creds = await register_driver(http, self.idx)
        if not creds:
            return False
        self.token = creds["token"]
        self.user_id = creds["userId"]
        self.truck_type = creds["truckType"]
        return True

    def _headers(self) -> dict:
        return {"Authorization": f"Bearer {self.token}"}

    async def _upload_placeholder_docs(self, http: httpx.AsyncClient) -> None:
        dummy_content = b"placeholder"
        for doc_type in ("drivingLicense", "vehicleRegistration", "vehiclePhoto"):
            try:
                await http.post(
                    f"{config.BASE_URL}/drivers/me/documents/{doc_type}",
                    headers=self._headers(),
                    files={"file": (f"{doc_type}.jpg", dummy_content, "image/jpeg")},
                )
            except Exception as exc:
                logger.debug("%s doc upload %s: %s", self.label, doc_type, exc)

    async def _wait_for_approval(self, http: httpx.AsyncClient, timeout: float = 120) -> bool:
        deadline = time.time() + timeout
        while time.time() < deadline and not self.stop_event.is_set():
            try:
                resp = await http.get(
                    f"{config.BASE_URL}/drivers/me/approval-status",
                    headers=self._headers(),
                )
                if resp.status_code == 200:
                    data = resp.json()
                    if data.get("approvalStatus") == "approved":
                        return True
            except Exception:
                pass
            await asyncio.sleep(3)
        return False

    async def _run_socket(self) -> None:
        sio = socketio.AsyncClient(
            logger=False,
            engineio_logger=False,
            reconnection=True,
            reconnection_attempts=5,
            ssl_verify=False,
        )

        @sio.event
        async def connect():
            logger.debug("%s socket connected", self.label)
            await sio.emit("driver:online")
            await self._send_location(sio)

        @sio.on("driver:trip_request")
        async def on_trip_request(data):
            trip_id = data.get("tripId")
            logger.debug("%s received trip_request %s", self.label, trip_id)
            await reporter.record_offer_received(trip_id)
            await self._pending_offer.put(data)

        @sio.on("driver:offer_expired")
        async def on_offer_expired(data):
            await reporter.record_offer_expired()
            logger.debug("%s offer_expired %s", self.label, data.get("tripId"))

        @sio.on("driver:trip_cancelled")
        async def on_trip_cancelled(data):
            self._active_trip_id = None
            logger.debug("%s trip cancelled: %s", self.label, data.get("tripId"))

        try:
            await sio.connect(
                config.WS_URL,
                auth={"token": self.token},
                transports=["websocket", "polling"],
                wait_timeout=15,
            )
        except Exception as exc:
            await reporter.record_error(self.label, "socket_connect", str(exc))
            return

        async def location_loop():
            while not self.stop_event.is_set() and sio.connected:
                await self._send_location(sio)
                await asyncio.sleep(8)

        location_task = asyncio.create_task(location_loop())

        try:
            while not self.stop_event.is_set():
                try:
                    offer = await asyncio.wait_for(
                        self._pending_offer.get(),
                        timeout=1.0,
                    )
                    await self._handle_offer(sio, offer)
                except asyncio.TimeoutError:
                    pass
        finally:
            location_task.cancel()
            if sio.connected:
                await sio.emit("driver:offline")
                await sio.disconnect()

    async def _send_location(self, sio: socketio.AsyncClient) -> None:
        lat = random.uniform(config.LAT_MIN, config.LAT_MAX)
        lng = random.uniform(config.LNG_MIN, config.LNG_MAX)
        try:
            await sio.emit(
                "driver:location_update",
                {
                    "lat": lat,
                    "lng": lng,
                    "heading": random.uniform(0, 360),
                    "speed": random.uniform(0, 80),
                },
            )
        except Exception:
            pass

    async def _handle_offer(self, sio: socketio.AsyncClient, offer: dict) -> None:
        if self._active_trip_id:
            return

        trip_id = offer.get("tripId")
        if not trip_id:
            return

        expires_ts = _parse_expires_at(offer)
        if expires_ts is not None and time.time() >= expires_ts:
            await reporter.record_late_offer_seen()
            return

        if random.random() < config.DRIVER_ACCEPT_RATE:
            await self._accept_trip(sio, trip_id)
        else:
            await self._reject_trip(sio, trip_id)

    async def _accept_trip(self, sio: socketio.AsyncClient, trip_id: str) -> None:
        """Single accept path via HTTP (avoids double-accept 409 from socket + HTTP)."""
        offer_received_at = time.time()
        async with httpx.AsyncClient(timeout=config.HTTP_TIMEOUT) as http:
            try:
                resp = await http.post(
                    f"{config.BASE_URL}/trips/{trip_id}/accept",
                    headers=self._headers(),
                )
                if resp.status_code == 200:
                    await reporter.record_offer_accepted(time.time() - offer_received_at)
                    self._active_trip_id = trip_id
                    logger.info("%s accepted trip %s", self.label, trip_id)
                    try:
                        await sio.emit("trip:join", {"tripId": trip_id})
                    except Exception:
                        pass
                    await self._advance_statuses(http, sio, trip_id)
                    return
                if resp.status_code == 409:
                    body = resp.json() if resp.content else {}
                    code = body.get("code", "")
                    if code == "OFFER_EXPIRED":
                        await reporter.record_accept_after_expiry_blocked()
                    elif code == "TRIP_NOT_AVAILABLE":
                        await reporter.record_accept_conflict()
                    else:
                        await reporter.record_accept_conflict()
                    return
                await reporter.record_error(
                    self.label,
                    "accept_trip",
                    f"HTTP {resp.status_code}",
                )
            except Exception as exc:
                await reporter.record_error(self.label, "accept_trip", str(exc))

    async def _reject_trip(self, sio: socketio.AsyncClient, trip_id: str) -> None:
        async with httpx.AsyncClient(timeout=config.HTTP_TIMEOUT) as http:
            try:
                resp = await http.post(
                    f"{config.BASE_URL}/trips/{trip_id}/reject",
                    headers=self._headers(),
                )
                if resp.status_code not in (204, 404, 409):
                    await reporter.record_error(
                        self.label,
                        "reject_trip",
                        f"HTTP {resp.status_code}",
                    )
            except Exception as exc:
                await reporter.record_error(self.label, "reject_trip", str(exc))

    async def _advance_statuses(
        self,
        http: httpx.AsyncClient,
        sio: socketio.AsyncClient,
        trip_id: str,
    ) -> None:
        for status in STATUS_CHAIN:
            if self.stop_event.is_set() or self._active_trip_id != trip_id:
                return
            await asyncio.sleep(random.uniform(0.8, 1.5))
            try:
                resp = await http.put(
                    f"{config.BASE_URL}/trips/{trip_id}/status",
                    headers=self._headers(),
                    json={"status": status},
                )
                if resp.status_code != 200:
                    await reporter.record_error(
                        self.label,
                        f"status_update:{status}",
                        f"HTTP {resp.status_code}",
                    )
                    return
                try:
                    await sio.emit(
                        "trip:status_update",
                        {"tripId": trip_id, "status": status},
                    )
                except Exception:
                    pass
                logger.debug("%s trip %s → %s", self.label, trip_id, status)
            except Exception as exc:
                await reporter.record_error(self.label, f"status_update:{status}", str(exc))
                return

        self._active_trip_id = None

    async def _clear_stale_active_trip(self, http: httpx.AsyncClient) -> None:
        try:
            resp = await http.get(
                f"{config.BASE_URL}/drivers/me/active-trip",
                headers=self._headers(),
            )
            if resp.status_code != 200:
                return
            trip = resp.json().get("trip")
            if not trip:
                return
            trip_id = trip.get("id") or trip.get("_id")
            if not trip_id:
                return
            for status in STATUS_CHAIN:
                r = await http.put(
                    f"{config.BASE_URL}/trips/{trip_id}/status",
                    headers=self._headers(),
                    json={"status": status},
                )
                if r.status_code != 200:
                    break
            logger.debug("%s cleared stale trip %s", self.label, trip_id)
        except Exception as exc:
            logger.debug("%s clear_stale_trip: %s", self.label, exc)

    async def run(self) -> None:
        async with httpx.AsyncClient(timeout=config.HTTP_TIMEOUT) as http:
            if not await self._register(http):
                return

            await self._clear_stale_active_trip(http)
            await self._upload_placeholder_docs(http)

            approved = await self._wait_for_approval(http, timeout=180)
            if not approved:
                await reporter.record_error(
                    self.label,
                    "approval_wait",
                    "Timed out waiting for approval",
                )
                return

            logger.info("%s approved, going online", self.label)

        await self._run_socket()
