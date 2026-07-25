#!/usr/bin/env python3
"""
Entry point for the Tashila API simulation test suite.

Usage:
    python scripts/simulate/run_simulation.py

Environment variables:
    SIM_BASE_URL            Railway API URL (default: https://tashila-api-production.up.railway.app)
    SIM_SECRET              X-Sim-Secret header value for the OTP endpoint (default: sim-secret-2024)
    ADMIN_EMAIL             Admin login email
    ADMIN_PASSWORD          Admin login password
    SIM_NUM_CLIENTS         Number of virtual clients  (default: 100)
    SIM_NUM_DRIVERS         Number of virtual drivers  (default: 30)
    SIM_TRIP_CYCLES         Trip cycles per client     (default: 3)
"""
from __future__ import annotations

import asyncio
import logging
import os
import sys

# Ensure the repo root is on the path so imports resolve
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from scripts.simulate import config, reporter
from scripts.simulate.actors.admin import VirtualAdmin
from scripts.simulate.actors.client import VirtualClient
from scripts.simulate.actors.driver import VirtualDriver

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(name)s  %(message)s",
    datefmt="%H:%M:%S",
)
logging.getLogger("socketio").setLevel(logging.WARNING)
logging.getLogger("engineio").setLevel(logging.WARNING)
logging.getLogger("httpx").setLevel(logging.WARNING)
logger = logging.getLogger("sim.runner")


async def _safe_run(coro, label: str) -> None:
    """Run a coroutine, catch all exceptions and record them."""
    try:
        await coro
    except Exception as exc:
        await reporter.record_error(label, "unhandled_exception", str(exc))


async def main() -> None:
    admin_email    = os.environ.get("ADMIN_EMAIL", "admin@tashila.com")
    admin_password = os.environ.get("ADMIN_PASSWORD", "Admin1234!")

    num_clients = config.NUM_CLIENTS
    num_drivers = config.NUM_DRIVERS

    logger.info(
        "Starting simulation: %d clients, %d drivers, base_url=%s",
        num_clients, num_drivers, config.BASE_URL,
    )

    stop_event = asyncio.Event()
    reporter.start_timer()

    # Build actor coroutines
    client_coros = [
        _safe_run(VirtualClient(i, stop_event).run(), f"client-{i}")
        for i in range(num_clients)
    ]
    driver_coros = [
        _safe_run(VirtualDriver(i, stop_event).run(), f"driver-{i}")
        for i in range(num_drivers)
    ]
    admin = VirtualAdmin(admin_email, admin_password)
    admin_coro = _safe_run(admin.run(stop_event), "admin")

    # Run drivers first for a head-start so they are online when clients start
    logger.info("Starting drivers…")
    driver_tasks = [asyncio.create_task(c) for c in driver_coros]

    # Small stagger so drivers have time to register/approve
    await asyncio.sleep(2)

    logger.info("Starting admin…")
    admin_task = asyncio.create_task(admin_coro)

    # Give admin time to approve drivers and let them go online before clients start
    await asyncio.sleep(12)

    logger.info("Starting clients…")
    client_tasks = []
    for i, coro in enumerate(client_coros):
        client_tasks.append(asyncio.create_task(coro))
        if i < len(client_coros) - 1:
            await asyncio.sleep(2)

    # Wait for all clients to finish their trip cycles
    await asyncio.gather(*client_tasks, return_exceptions=True)
    logger.info("All clients done.")

    # Signal drivers & admin to wind down
    stop_event.set()

    # Give drivers/admin a moment to clean up
    await asyncio.gather(*driver_tasks, admin_task, return_exceptions=True)

    error_count = reporter.print_report(num_clients, num_drivers)
    sys.exit(1 if error_count > 0 else 0)


if __name__ == "__main__":
    asyncio.run(main())
