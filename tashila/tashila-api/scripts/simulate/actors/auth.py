"""Shared auth helpers: OTP register + login for clients and drivers."""
from __future__ import annotations

import asyncio
import random
import string

import httpx

from scripts.simulate import config
from scripts.simulate import reporter


def _client_phone(idx: int) -> str:
    return f"+213000{idx:06d}"


def _driver_phone(idx: int) -> str:
    return f"+213001{idx:06d}"


def _random_plate() -> str:
    letters = "".join(random.choices(string.ascii_uppercase, k=3))
    digits = random.randint(100, 999)
    return f"{digits}-{letters}-{digits}"


async def _fetch_otp(http: httpx.AsyncClient, phone: str, role: str) -> str | None:
    """Retrieve OTP from the simulation endpoint."""
    for attempt in range(10):
        await asyncio.sleep(1.0 + attempt * 0.5)
        try:
            resp = await http.get(
                f"{config.BASE_URL}/auth/sim/otp",
                params={"phone": phone, "role": role},
                headers={"X-Sim-Secret": config.SIM_SECRET},
            )
            if resp.status_code == 200:
                return resp.json()["otp"]
        except Exception:
            pass
    return None


async def register_and_login(
    http: httpx.AsyncClient,
    phone: str,
    role: str,
    actor_label: str,
) -> dict | None:
    """Send OTP, retrieve it from the sim endpoint, verify, return {token, userId}."""
    try:
        # Send OTP
        send_resp = await http.post(
            f"{config.BASE_URL}/auth/otp/send",
            json={"phone": phone, "role": role},
        )
        if send_resp.status_code != 200:
            await reporter.record_error(actor_label, "otp/send", f"HTTP {send_resp.status_code}: {send_resp.text[:100]}")
            return None

        otp = await _fetch_otp(http, phone, role)
        if not otp:
            await reporter.record_error(actor_label, "otp/fetch", "OTP not found after retries")
            return None

        # Verify OTP
        verify_resp = await http.post(
            f"{config.BASE_URL}/auth/otp/verify",
            json={"phone": phone, "otp": otp, "role": role},
        )
        if verify_resp.status_code != 200:
            await reporter.record_error(actor_label, "otp/verify", f"HTTP {verify_resp.status_code}: {verify_resp.text[:100]}")
            return None

        data = verify_resp.json()
        return {
            "token": data["accessToken"],
            "userId": data["user"]["id"],
            "phone": phone,
        }
    except Exception as exc:
        await reporter.record_error(actor_label, "register_and_login", str(exc))
        return None


async def register_client(http: httpx.AsyncClient, idx: int) -> dict | None:
    phone = _client_phone(idx)
    actor = f"client-{idx}"
    creds = await register_and_login(http, phone, "client", actor)
    if not creds:
        return None

    # Profile setup
    headers = {"Authorization": f"Bearer {creds['token']}"}
    try:
        setup_resp = await http.post(
            f"{config.BASE_URL}/users/me/profile-setup",
            json={"name": f"Client {idx}", "locale": "ar"},
            headers=headers,
        )
        if setup_resp.status_code not in (200, 409):
            await reporter.record_error(actor, "profile-setup", f"HTTP {setup_resp.status_code}")
    except Exception as exc:
        await reporter.record_error(actor, "profile-setup", str(exc))

    return creds


async def register_driver(http: httpx.AsyncClient, idx: int) -> dict | None:
    phone = _driver_phone(idx)
    actor = f"driver-{idx}"
    creds = await register_and_login(http, phone, "driver", actor)
    if not creds:
        return None

    # All sim drivers use single_cabin so client trips always match a candidate pool
    truck_type = config.TRUCK_TYPES[0]
    headers = {"Authorization": f"Bearer {creds['token']}"}

    try:
        setup_resp = await http.post(
            f"{config.BASE_URL}/drivers/me/profile-setup",
            json={
                "name": f"Driver {idx}",
                "truckType": truck_type,
                "vehiclePlate": _random_plate(),
                "vehicleColor": "White",
                "vehicleModel": "Toyota Hilux",
            },
            headers=headers,
        )
        if setup_resp.status_code not in (200, 409):
            await reporter.record_error(actor, "driver-profile-setup", f"HTTP {setup_resp.status_code}")
    except Exception as exc:
        await reporter.record_error(actor, "driver-profile-setup", str(exc))

    creds["truckType"] = truck_type
    return creds
