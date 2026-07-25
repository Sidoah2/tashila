import logging
from typing import Any

import httpx

from app.core.config import settings
from app.core.database import get_database

logger = logging.getLogger(__name__)

PUSH_TOKENS_COLLECTION = "push_tokens"
FCM_URL = "https://fcm.googleapis.com/fcm/send"


def _fcm_data_payload(data: dict[str, Any]) -> dict[str, str]:
    payload: dict[str, str] = {}
    for key, value in data.items():
        if value is None:
            continue
        payload[str(key)] = str(value)
    return payload


async def _delete_push_token(owner_id: str, role: str) -> None:
    await get_database()[PUSH_TOKENS_COLLECTION].delete_one(
        {"ownerId": owner_id, "role": role},
    )


async def _send_fcm(
    token: str,
    title: str,
    body: str,
    data: dict[str, Any],
    owner_id: str,
    role: str,
) -> bool:
    if not settings.fcm_server_key:
        logger.warning("FCM server key not configured; push skipped for %s/%s", role, owner_id)
        return False

    headers = {
        "Authorization": f"key={settings.fcm_server_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "to": token,
        "notification": {"title": title, "body": body},
        "data": _fcm_data_payload(data),
    }

    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.post(FCM_URL, headers=headers, json=payload)

    if response.status_code == 401:
        logger.error("FCM key invalid")
        return False

    if response.status_code == 400:
        logger.info("FCM rejected token for %s/%s; removing registration", role, owner_id)
        await _delete_push_token(owner_id, role)
        return False

    if response.status_code >= 400:
        logger.warning(
            "FCM push failed for %s/%s: HTTP %s %s",
            role,
            owner_id,
            response.status_code,
            response.text[:200],
        )
        return False

    try:
        result = response.json()
    except Exception:
        return True

    if result.get("failure", 0) > 0:
        results = result.get("results") or []
        for entry in results:
            error = entry.get("error", "")
            if error in ("InvalidRegistration", "NotRegistered", "MismatchSenderId"):
                await _delete_push_token(owner_id, role)
                return False
        return False

    return True


async def send_push(
    owner_id: str,
    role: str,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> bool:
    try:
        token_doc = await get_database()[PUSH_TOKENS_COLLECTION].find_one(
            {"ownerId": owner_id, "role": role},
        )
        if token_doc is None:
            return False

        platform = token_doc.get("platform", "fcm")
        token = token_doc.get("token", "")
        if not token:
            return False

        push_data = dict(data or {})

        if platform == "fcm":
            return await _send_fcm(token, title, body, push_data, owner_id, role)

        logger.debug("Push platform %s not supported for %s/%s", platform, role, owner_id)
        return False
    except Exception:
        logger.exception("Push failed for %s/%s", role, owner_id)
        return False


# --- Convenience wrappers ---


async def push_trip_accepted(client_id: str, driver_name: str, trip_id: str) -> bool:
    return await send_push(
        client_id,
        "client",
        "Trip accepted",
        f"{driver_name} accepted your trip.",
        {"type": "trip_accepted", "tripId": trip_id},
    )


async def push_trip_heading_to_pickup(client_id: str, trip_id: str) -> bool:
    return await send_push(
        client_id,
        "client",
        "Driver on the way",
        "Your driver is heading to the pickup location.",
        {"type": "trip_heading_to_pickup", "tripId": trip_id},
    )


async def push_trip_started(client_id: str, trip_id: str) -> bool:
    return await send_push(
        client_id,
        "client",
        "Trip started",
        "Your trip is now in progress.",
        {"type": "trip_started", "tripId": trip_id},
    )


async def push_trip_completed(client_id: str, driver_id: str, trip_id: str) -> bool:
    return await send_push(
        client_id,
        "client",
        "Trip completed",
        "Your trip has been completed.",
        {
            "type": "trip_completed",
            "tripId": trip_id,
            "driverId": driver_id,
        },
    )


async def push_trip_cancelled_by_driver(
    client_id: str,
    driver_name: str,
    trip_id: str,
) -> bool:
    return await send_push(
        client_id,
        "client",
        "Trip cancelled",
        f"{driver_name} cancelled the trip.",
        {"type": "trip_cancelled_by_driver", "tripId": trip_id},
    )


async def push_trip_request(driver_id: str, pickup_address: str, fare: float) -> bool:
    fare_str = f"{fare:.0f}" if fare == int(fare) else f"{fare:.2f}"
    return await send_push(
        driver_id,
        "driver",
        "New trip request",
        f"Pickup: {pickup_address} — {fare_str} DZD",
        {"type": "trip_request", "pickupAddress": pickup_address, "fare": fare_str},
    )


async def push_driver_approved(driver_id: str) -> bool:
    return await send_push(
        driver_id,
        "driver",
        "Account approved",
        "Your driver account has been approved. You can go online now.",
        {"type": "driver_approved"},
    )


async def push_document_status(
    driver_id: str,
    doc_type: str,
    approved: bool,
    reason: str | None = None,
) -> bool:
    label = doc_type.replace("_", " ").title()
    if approved:
        title = f"{label} approved"
        body = f"Your {label} has been approved."
        status = "approved"
    else:
        title = f"{label} rejected"
        body = reason or f"Your {label} was rejected."
        status = "rejected"

    return await send_push(
        driver_id,
        "driver",
        title,
        body,
        {
            "type": "document_status",
            "documentType": doc_type,
            "status": status,
        },
    )


# --- SMS ---

TRACCAR_SMS_URL = "https://www.traccar.org/sms/"


async def send_sms(phone: str, message: str) -> None:
    token = settings.traccar_sms_token
    if not token:
        if settings.is_production:
            logger.warning("SMS provider not configured, message not sent to %s", phone)
        else:
            print(f"[SMS] To: {phone} | {message}")
        return

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(
                TRACCAR_SMS_URL,
                headers={
                    "Authorization": token,
                    "Content-Type": "application/json",
                },
                json={"to": phone, "message": message},
            )
        if resp.status_code == 200:
            data = resp.json()
            if data.get("successCount", 0) > 0:
                logger.info("SMS sent to %s via Traccar", phone)
            else:
                logger.warning("Traccar SMS failed for %s: %s", phone, resp.text[:200])
        else:
            logger.warning("Traccar SMS HTTP %s for %s: %s", resp.status_code, phone, resp.text[:200])
    except Exception:
        logger.exception("SMS send error for %s", phone)


# Backwards-compatible aliases
class NotificationService:
    send_sms = staticmethod(send_sms)
    send_push = staticmethod(send_push)
    send_push_to_owner = staticmethod(send_push)

    @staticmethod
    async def notify_client_trip_accepted(client_id: str, trip_id: str) -> bool:
        return await push_trip_accepted(client_id, "A driver", trip_id)
