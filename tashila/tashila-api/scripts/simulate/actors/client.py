"""VirtualClient: registers, connects via Socket.IO, creates trips, waits for completion, rates."""
from __future__ import annotations

import asyncio
import logging
import random
import time

import httpx
import socketio

from scripts.simulate import config, reporter
from scripts.simulate.actors.auth import register_client

logger = logging.getLogger("sim.client")


def _random_coords() -> tuple[float, float]:
    return (
        random.uniform(config.LAT_MIN, config.LAT_MAX),
        random.uniform(config.LNG_MIN, config.LNG_MAX),
    )


def _pickup_addr(lat: float, lng: float) -> str:
    return f"{lat:.4f},{lng:.4f} Algiers"


class VirtualClient:
    def __init__(self, idx: int, stop_event: asyncio.Event) -> None:
        self.idx = idx
        self.label = f"client-{idx}"
        self.stop_event = stop_event
        self.token = ""
        self.user_id = ""
        self._sio: socketio.AsyncClient | None = None

        # Maps trip_id → event
        self._driver_assigned: dict[str, asyncio.Event] = {}
        self._no_drivers: dict[str, asyncio.Event] = {}
        self._trip_completed: dict[str, asyncio.Event] = {}
        self._latest_status: dict[str, str] = {}

    async def _register(self, http: httpx.AsyncClient) -> bool:
        creds = await register_client(http, self.idx)
        if not creds:
            return False
        self.token = creds["token"]
        self.user_id = creds["userId"]
        return True

    def _headers(self) -> dict:
        return {"Authorization": f"Bearer {self.token}"}

    # ------------------------------------------------------------------ #
    # Socket.IO                                                            #
    # ------------------------------------------------------------------ #

    async def _connect_socket(self) -> bool:
        self._sio = socketio.AsyncClient(logger=False, engineio_logger=False, reconnection=True, reconnection_attempts=3, ssl_verify=False)
        sio = self._sio

        @sio.on("trip:driver_assigned")
        async def on_driver_assigned(data):
            trip_id = data.get("tripId") or data.get("trip", {}).get("id")
            logger.debug("%s driver_assigned trip=%s", self.label, trip_id)
            if trip_id and trip_id in self._driver_assigned:
                self._driver_assigned[trip_id].set()

        @sio.on("trip:no_drivers_found")
        async def on_no_drivers(data):
            trip_id = data.get("tripId")
            logger.debug("%s no_drivers trip=%s", self.label, trip_id)
            if trip_id and trip_id in self._no_drivers:
                self._no_drivers[trip_id].set()

        @sio.on("trip:status_changed")
        async def on_status_changed(data):
            trip_id = data.get("tripId")
            status = data.get("status")
            self._latest_status[trip_id] = status
            logger.debug("%s trip %s → %s", self.label, trip_id, status)
            if status == "completed" and trip_id in self._trip_completed:
                self._trip_completed[trip_id].set()

        try:
            await sio.connect(
                config.WS_URL,
                auth={"token": self.token},
                transports=["websocket", "polling"],
                wait_timeout=15,
            )
            return True
        except Exception as exc:
            await reporter.record_error(self.label, "socket_connect", str(exc))
            return False

    async def _join_trip_room(self, trip_id: str) -> None:
        if self._sio and self._sio.connected:
            try:
                await self._sio.emit("trip:join", {"tripId": trip_id})
            except Exception:
                pass

    # ------------------------------------------------------------------ #
    # Trip lifecycle                                                       #
    # ------------------------------------------------------------------ #

    async def _estimate_fare(self, http: httpx.AsyncClient, pickup: dict, dropoff: dict, truck_type: str) -> float | None:
        try:
            resp = await http.post(
                f"{config.BASE_URL}/trips/estimate",
                json={"pickup": pickup, "dropoff": dropoff, "truckType": truck_type},
                headers=self._headers(),
            )
            if resp.status_code == 200:
                return resp.json().get("fare")
        except Exception as exc:
            await reporter.record_error(self.label, "estimate_fare", str(exc))
        return None

    async def _cancel_active_trips(self, http: httpx.AsyncClient) -> None:
        """Cancel any lingering active trip from a previous run."""
        try:
            resp = await http.get(
                f"{config.BASE_URL}/users/me/trips",
                params={"limit": 5},
                headers=self._headers(),
            )
            if resp.status_code != 200:
                return
            data = resp.json()
            if isinstance(data, list):
                trips = data
            elif isinstance(data, dict):
                trips = data.get("items") or data.get("trips") or []
            else:
                trips = []
            active_statuses = {
                "requested",
                "accepted",
                "headingToPickup",
                "inProgress",
                "awaitingCash",
            }
            for t in trips:
                if t.get("status") in active_statuses:
                    trip_id = t.get("id") or str(t.get("_id", ""))
                    if trip_id:
                        await http.delete(
                            f"{config.BASE_URL}/trips/{trip_id}",
                            headers=self._headers(),
                        )
                        logger.debug("%s cancelled leftover trip %s", self.label, trip_id)
        except Exception as exc:
            logger.debug("%s cancel_active_trips error: %s", self.label, exc)

    async def _create_trip(self, http: httpx.AsyncClient) -> dict | None:
        p_lat, p_lng = _random_coords()
        d_lat, d_lng = _random_coords()
        # Match the majority of sim drivers (idx % 2 → single_cabin for even indices)
        truck_type = config.TRUCK_TYPES[0]

        pickup = {
            "lat": p_lat, "lng": p_lng,
            "address": _pickup_addr(p_lat, p_lng),
        }
        dropoff = {
            "lat": d_lat, "lng": d_lng,
            "address": _pickup_addr(d_lat, d_lng),
        }

        await _estimate_fare_safe(self, http, pickup, dropoff, truck_type)

        try:
            resp = await http.post(
                f"{config.BASE_URL}/trips",
                json={
                    "pickup": pickup,
                    "dropoff": dropoff,
                    "truckType": truck_type,
                    "paymentMethod": "cash",
                    "notes": "",
                },
                headers=self._headers(),
            )
            if resp.status_code in (200, 201):
                await reporter.record_trip_created()
                trip = resp.json()
                return trip.get("trip") or trip
            if resp.status_code == 409:
                # Existing active trip – cancel it and retry once
                await self._cancel_active_trips(http)
                await asyncio.sleep(1)
                retry = await http.post(
                    f"{config.BASE_URL}/trips",
                    json={
                        "pickup": pickup,
                        "dropoff": dropoff,
                        "truckType": truck_type,
                        "paymentMethod": "cash",
                        "notes": "",
                    },
                    headers=self._headers(),
                )
                if retry.status_code in (200, 201):
                    await reporter.record_trip_created()
                    trip = retry.json()
                    return trip.get("trip") or trip
                # If still failing, skip cycle silently
                return None
            await reporter.record_error(self.label, "create_trip", f"HTTP {resp.status_code}: {resp.text[:100]}")
        except Exception as exc:
            await reporter.record_error(self.label, "create_trip", str(exc))
        return None

    async def _run_single_trip(self, http: httpx.AsyncClient) -> None:
        trip = await self._create_trip(http)
        if not trip:
            return

        trip_id = trip.get("id") or str(trip.get("_id", ""))
        if not trip_id:
            await reporter.record_error(self.label, "create_trip", "no tripId in response")
            return

        # Register event handles before joining
        assigned_evt = asyncio.Event()
        no_driver_evt = asyncio.Event()
        completed_evt = asyncio.Event()
        self._driver_assigned[trip_id] = assigned_evt
        self._no_drivers[trip_id] = no_driver_evt
        self._trip_completed[trip_id] = completed_evt

        await self._join_trip_room(trip_id)

        create_time = time.time()

        # Wait for driver assignment or no-driver
        try:
            done, _ = await asyncio.wait(
                [
                    asyncio.create_task(assigned_evt.wait()),
                    asyncio.create_task(no_driver_evt.wait()),
                ],
                timeout=240,
                return_when=asyncio.FIRST_COMPLETED,
            )
        except Exception:
            done = set()

        if no_driver_evt.is_set():
            await reporter.record_trip_no_driver()
            self._cleanup_trip(trip_id)
            return

        if not assigned_evt.is_set():
            # Timeout – no offer came
            await reporter.record_trip_no_driver()
            self._cleanup_trip(trip_id)
            return

        accept_latency = time.time() - create_time
        await reporter.record_trip_accepted(accept_latency)
        accept_time = time.time()

        # Wait for completion
        try:
            await asyncio.wait_for(completed_evt.wait(), timeout=config.TRIP_COMPLETE_TIMEOUT)
        except asyncio.TimeoutError:
            await reporter.record_error(self.label, "trip_complete_timeout", f"trip {trip_id}")
            self._cleanup_trip(trip_id)
            return

        complete_latency = time.time() - accept_time
        await reporter.record_trip_completed(complete_latency)
        self._cleanup_trip(trip_id)

        # Rate the driver
        await self._rate_trip(http, trip_id)

    def _cleanup_trip(self, trip_id: str) -> None:
        self._driver_assigned.pop(trip_id, None)
        self._no_drivers.pop(trip_id, None)
        self._trip_completed.pop(trip_id, None)
        self._latest_status.pop(trip_id, None)

    async def _rate_trip(self, http: httpx.AsyncClient, trip_id: str) -> None:
        try:
            resp = await http.post(
                f"{config.BASE_URL}/trips/{trip_id}/rate-driver",
                json={"rating": random.choice([4, 5]), "comment": "Simulation"},
                headers=self._headers(),
            )
            if resp.status_code not in (200, 409):
                await reporter.record_error(self.label, "rate_driver", f"HTTP {resp.status_code}")
        except Exception as exc:
            await reporter.record_error(self.label, "rate_driver", str(exc))

    # ------------------------------------------------------------------ #
    # Main                                                                 #
    # ------------------------------------------------------------------ #

    async def run(self) -> None:
        async with httpx.AsyncClient(timeout=config.HTTP_TIMEOUT) as http:
            if not await self._register(http):
                return

            # Clean up any stale trips from previous simulation runs
            await self._cancel_active_trips(http)

            if not await self._connect_socket():
                return

            for cycle in range(config.TRIP_CYCLES_PER_CLIENT):
                if self.stop_event.is_set():
                    break
                await self._run_single_trip(http)
                if cycle < config.TRIP_CYCLES_PER_CLIENT - 1:
                    delay = random.uniform(config.INTER_TRIP_DELAY_MIN, config.INTER_TRIP_DELAY_MAX)
                    await asyncio.sleep(delay)

            if self._sio and self._sio.connected:
                await self._sio.disconnect()


async def _estimate_fare_safe(client: VirtualClient, http: httpx.AsyncClient, pickup: dict, dropoff: dict, truck_type: str) -> float | None:
    return await client._estimate_fare(http, pickup, dropoff, truck_type)
