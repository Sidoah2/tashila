"""VirtualAdmin: logs in, continuously approves pending drivers, collects final stats."""
from __future__ import annotations

import asyncio
import logging

import httpx

from scripts.simulate import config
from scripts.simulate import reporter

logger = logging.getLogger("sim.admin")


class VirtualAdmin:
    def __init__(self, email: str, password: str) -> None:
        self.email = email
        self.password = password
        self.token: str = ""
        self._stop = asyncio.Event()
        self.final_stats: dict = {}

    async def _login(self, http: httpx.AsyncClient) -> bool:
        try:
            resp = await http.post(
                f"{config.BASE_URL}/auth/admin/login",
                json={"email": self.email, "password": self.password},
            )
            if resp.status_code == 200:
                self.token = resp.json()["accessToken"]
                logger.info("Admin logged in")
                return True
            await reporter.record_error("admin", "login", f"HTTP {resp.status_code}")
            return False
        except Exception as exc:
            await reporter.record_error("admin", "login", str(exc))
            return False

    def _headers(self) -> dict:
        return {"Authorization": f"Bearer {self.token}"}

    async def _approve_pending(self, http: httpx.AsyncClient) -> None:
        try:
            resp = await http.get(
                f"{config.BASE_URL}/admin/drivers/pending-approval",
                headers=self._headers(),
            )
            if resp.status_code != 200:
                return
            drivers = resp.json()
            for driver in drivers:
                driver_id = driver.get("id") or driver.get("_id")
                if not driver_id:
                    continue
                await http.put(
                    f"{config.BASE_URL}/admin/drivers/{driver_id}/approval",
                    json={"status": "approved"},
                    headers=self._headers(),
                )
                logger.debug("Approved driver %s", driver_id)
        except Exception as exc:
            logger.debug("approve_pending error: %s", exc)

    async def _collect_stats(self, http: httpx.AsyncClient) -> None:
        try:
            resp = await http.get(
                f"{config.BASE_URL}/admin/stats/dashboard",
                headers=self._headers(),
            )
            if resp.status_code == 200:
                self.final_stats = resp.json()
        except Exception:
            pass

    async def run(self, stop_event: asyncio.Event) -> None:
        async with httpx.AsyncClient(timeout=config.HTTP_TIMEOUT) as http:
            if not await self._login(http):
                return

            while not stop_event.is_set():
                await self._approve_pending(http)
                try:
                    await asyncio.wait_for(stop_event.wait(), timeout=config.ADMIN_POLL_INTERVAL)
                except asyncio.TimeoutError:
                    pass

            await self._collect_stats(http)
            if self.final_stats:
                logger.info("Dashboard KPIs: %s", self.final_stats)
