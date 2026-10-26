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


def _send_via_firebase_admin(
    token: str,
    title: str,
    body: str,
    data: dict[str, str],
    channel_id: str = "driver_trip_offers",
    apns_category: str | None = None,
) -> bool:
    try:
        from app.services.auth_service import _get_firebase_app
        from firebase_admin import messaging
        app = _get_firebase_app()
        if not app:
            return False

        clean_data = dict(data)
        clean_data.setdefault("title", title)
        clean_data.setdefault("body", body)

        apns_config = None
        if apns_category:
            apns_config = messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        category=apns_category,
                        sound="default",
                        content_available=True,
                        alert=messaging.ApsAlert(title=title, body=body),
                    ),
                ),
            )

        # For interactive notifications (e.g. driver_inactivity_check):
        # On Android, flutter_local_notifications creates the rich notification with action buttons.
        # If top-level `notification` is included, Google Play Services automatically renders a
        # second, redundant plain notification (without buttons).
        is_interactive = bool(apns_category or clean_data.get("type") == "driver_inactivity_check")

        notification_payload = None if is_interactive else messaging.Notification(title=title, body=body)

        android_config = messaging.AndroidConfig(priority="high")
        if not is_interactive:
            android_config = messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id=channel_id,
                    priority="high",
                    default_sound=True,
                    click_action="FLUTTER_NOTIFICATION_CLICK",
                ),
            )

        message = messaging.Message(
            token=token,
            notification=notification_payload,
            data=clean_data,
            android=android_config,
            apns=apns_config,
        )
        messaging.send(message, app=app)
        return True
    except Exception as exc:
        logger.warning("Firebase Admin messaging send failed: %s", exc)
        return False


async def _send_fcm(
    token: str,
    title: str,
    body: str,
    data: dict[str, Any],
    owner_id: str,
    role: str,
    channel_id: str = "driver_trip_offers",
    apns_category: str | None = None,
) -> bool:
    clean_data = _fcm_data_payload(data)
    # 1. Try modern Firebase Admin SDK first (HTTP v1)
    if _send_via_firebase_admin(token, title, body, clean_data, channel_id=channel_id, apns_category=apns_category):
        logger.info("FCM push sent via Firebase Admin SDK to %s/%s", role, owner_id)
        return True

    # 2. Fallback to legacy FCM server key if configured
    if not settings.fcm_server_key:
        logger.warning("FCM push skipped for %s/%s (no server key / admin failed)", role, owner_id)
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
    channel_id: str = "driver_trip_offers",
    apns_category: str | None = None,
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
            return await _send_fcm(
                token,
                title,
                body,
                push_data,
                owner_id,
                role,
                channel_id=channel_id,
                apns_category=apns_category,
            )

        logger.debug("Push platform %s not supported for %s/%s", platform, role, owner_id)
        return False
    except Exception:
        logger.exception("Push failed for %s/%s", role, owner_id)
        return False


# --- Convenience wrappers ---


async def push_driver_inactivity_check(driver_id: str) -> bool:
    title = "هل ما زلت متاحاً للعمل؟"
    body = "أنت متصل في وضع الاستعداد منذ 15 دقيقة دون نشاط في التطبيق."
    payload = {
        "type": "driver_inactivity_check",
        "category": "INACTIVITY_CHECK",
        "action_stay_online": "ACTION_STAY_ONLINE",
        "action_go_offline": "ACTION_GO_OFFLINE",
    }
    return await send_push(
        driver_id,
        "driver",
        title,
        body,
        payload,
        channel_id="driver_inactivity_check",
        apns_category="INACTIVITY_CHECK",
    )


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


async def push_trip_request(
    driver_id: str,
    pickup_address: str,
    fare: float,
    trip_id: str | None = None,
    dropoff_address: str | None = None,
) -> bool:
    fare_str = f"{fare:.0f}" if fare == int(fare) else f"{fare:.2f}"
    title = "طلب رحلة جديد"
    if dropoff_address and dropoff_address.strip():
        body = f"الانطلاق: {pickup_address}\nالوصول: {dropoff_address}\nالسعر: {fare_str} دج"
    else:
        body = f"الانطلاق: {pickup_address}\nالسعر: {fare_str} دج"

    payload: dict[str, Any] = {
        "type": "trip_request",
        "pickupAddress": pickup_address,
        "dropoffAddress": dropoff_address or "",
        "fare": fare_str,
    }
    if trip_id:
        payload["tripId"] = trip_id
    return await send_push(
        driver_id,
        "driver",
        title,
        body,
        payload,
    )


async def push_driver_approved(driver_id: str) -> bool:
    return await send_push(
        driver_id,
        "driver",
        "تمت الموافقة على الحساب",
        "تم قبول حساب السائق الخاص بك. يمكنك بدء العمل واستقبال الطلبات الآن.",
        {"type": "driver_approved"},
    )


async def push_document_status(
    driver_id: str,
    doc_type: str,
    approved: bool,
    reason: str | None = None,
) -> bool:
    doc_labels = {
        "driving_license": "رخصة السياقة",
        "registration_card": "البطاقة الرمادية",
        "identity_card": "بطاقة التعريف",
        "criminal_record": "صحيفة السوابق العدلية",
        "insurance": "التأمين",
        "technical_inspection": "المراقبة التقنية",
    }
    label = doc_labels.get(doc_type, doc_type.replace("_", " ").title())
    if approved:
        title = f"تمت الموافقة على {label}"
        body = f"تم قبول وثيقة {label} بنجاح."
        status = "approved"
    else:
        title = f"تم رفض {label}"
        body = reason or f"تم رفض وثيقة {label}، يرجى إعادة رفعها."
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

async def send_sms(phone: str, message: str) -> None:
    # If SMSSAK is configured, send via SMSSAK API
    if settings.smssak_api_key and settings.smssak_project_id:
        try:
            import re
            cleaned = re.sub(r"[^\d+]", "", phone or "")
            if cleaned.startswith("+213"):
                local_phone = "0" + cleaned[4:]
                country_code = "dz"
            elif cleaned.startswith("213"):
                local_phone = "0" + cleaned[3:]
                country_code = "dz"
            elif cleaned.startswith("0") and len(cleaned) == 10:
                local_phone = cleaned
                country_code = "dz"
            elif len(cleaned) == 9 and cleaned[0] in ("5", "6", "7"):
                local_phone = "0" + cleaned
                country_code = "dz"
            else:
                local_phone = cleaned.lstrip("+")
                country_code = settings.smssak_country or "dz"

            url = settings.smssak_send_message_url or "https://sendmessage-47lvvvrp4a-uc.a.run.app"
            headers = {
                "Content-Type": "application/json",
                "key": settings.smssak_api_key
            }
            data = {
                "country": country_code.upper(),
                "phone": local_phone,
                "projectId": settings.smssak_project_id,
                "message": message
            }
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.post(url, headers=headers, json=data)
            if resp.status_code in (200, 201):
                logger.info("SMS sent to %s via SMSSAK", phone)
            else:
                logger.warning("SMSSAK SMS HTTP %s for %s: %s", resp.status_code, phone, resp.text[:200])
        except Exception:
            logger.exception("SMSSAK SMS send error for %s", phone)
        return

    # Fallback to Traccar Gateway
    url = settings.traccar_sms_url or "https://www.traccar.org/sms/"
    token = settings.traccar_sms_token
    
    # If using the default cloud relay, the token is mandatory.
    if "traccar.org" in url and not token:
        if settings.is_production:
            logger.warning("SMS provider not configured (missing token), message not sent to %s", phone)
        else:
            print(f"[SMS] To: {phone} | {message}")
        return

    try:
        headers = {
            "Content-Type": "application/json",
        }
        if token:
            headers["Authorization"] = token

        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(
                url,
                headers=headers,
                json={"to": phone, "message": message},
            )
        if resp.status_code == 200:
            try:
                data = resp.json()
            except Exception:
                data = {}
            
            # Cloud relay uses successCount > 0, local gateway might use success=True or just return 200 OK
            if (
                data.get("successCount", 0) > 0 
                or data.get("success", False) 
                or "traccar.org" not in url
            ):
                logger.info("SMS sent to %s via Traccar Gateway (%s)", phone, url)
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
