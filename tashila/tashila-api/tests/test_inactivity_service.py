from __future__ import annotations

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from bson import ObjectId

from app.services import inactivity_service, driver_service, notification_service


@pytest.mark.asyncio
async def test_push_driver_inactivity_check_payload() -> None:
    """Verifies the push notification includes APNs category, channel ID, and action identifiers."""
    with patch("app.services.notification_service.send_push", new_callable=AsyncMock) as mock_send:
        mock_send.return_value = True
        res = await notification_service.push_driver_inactivity_check("d-123")
        assert res is True
        mock_send.assert_awaited_once()
        args, kwargs = mock_send.call_args
        assert args[0] == "d-123"
        assert args[1] == "driver"
        assert "هل ما زلت متاحاً" in args[2]
        assert "15 دقيقة" in args[3]
        payload = args[4]
        assert payload["type"] == "driver_inactivity_check"
        assert payload["category"] == "INACTIVITY_CHECK"
        assert payload["action_stay_online"] == "ACTION_STAY_ONLINE"
        assert payload["action_go_offline"] == "ACTION_GO_OFFLINE"
        assert kwargs["channel_id"] == "driver_inactivity_check"
        assert kwargs["apns_category"] == "INACTIVITY_CHECK"


@pytest.mark.asyncio
async def test_record_heartbeat_updates_driver_fields() -> None:
    """Verifies that record_heartbeat updates lastActiveAt and clears alerts."""
    mock_db = MagicMock()
    mock_coll = MagicMock()
    mock_coll.update_one = AsyncMock(return_value=None)
    mock_db.__getitem__.return_value = mock_coll

    test_driver = {"_id": ObjectId(), "phone": "+213555000111", "availability": "online"}

    with (
        patch("app.services.driver_service._find_driver", new_callable=AsyncMock, return_value=test_driver),
        patch("app.services.driver_service.get_database", return_value=mock_db),
    ):
        res = await driver_service.record_heartbeat(str(test_driver["_id"]))
        assert res["status"] == "ok"
        assert "lastActiveAt" in res
        mock_coll.update_one.assert_awaited_once()
        update_call = mock_coll.update_one.call_args[0][1]
        set_dict = update_call["$set"]
        assert "lastActiveAt" in set_dict
        assert set_dict["lastInactivityAlertAt"] is None
        assert set_dict["unansweredInactivityAlerts"] == 0


@pytest.mark.asyncio
async def test_check_and_notify_inactive_drivers() -> None:
    """Verifies inactive online drivers receive notification, while active/recent ones do not."""
    now = datetime.now(timezone.utc)
    driver1_id = ObjectId()
    driver2_id = ObjectId()
    driver_auto_offline_id = ObjectId()

    # Driver 1: online, inactive for 20 mins, not alerted yet -> SHOULD BE NOTIFIED
    d1 = {
        "_id": driver1_id,
        "availability": "online",
        "approvalStatus": "approved",
        "lastActiveAt": now - timedelta(minutes=20),
        "lastInactivityAlertAt": None,
        "unansweredInactivityAlerts": 0,
    }

    # Driver 2: online, inactive for 25 mins, but alerted 5 mins ago -> SHOULD BE SKIPPED
    d2 = {
        "_id": driver2_id,
        "availability": "online",
        "approvalStatus": "approved",
        "lastActiveAt": now - timedelta(minutes=25),
        "lastInactivityAlertAt": now - timedelta(minutes=5),
        "unansweredInactivityAlerts": 1,
    }

    # Driver 3: has 4 unanswered alerts -> SHOULD BE AUTO-SWITCHED TO OFFLINE
    d3 = {
        "_id": driver_auto_offline_id,
        "availability": "online",
        "approvalStatus": "approved",
        "lastActiveAt": now - timedelta(minutes=65),
        "lastInactivityAlertAt": now - timedelta(minutes=16),
        "unansweredInactivityAlerts": 4,
    }

    class AsyncCursorMock:
        def __init__(self, items):
            self.items = list(items)

        def __aiter__(self):
            return self

        async def __anext__(self):
            if not self.items:
                raise StopAsyncIteration
            return self.items.pop(0)

    mock_db = MagicMock()
    mock_coll = MagicMock()
    mock_coll.find.return_value = AsyncCursorMock([d1, d2, d3])
    mock_coll.update_one = AsyncMock(return_value=None)
    mock_db.__getitem__.return_value = mock_coll

    with (
        patch("app.services.inactivity_service.get_database", return_value=mock_db),
        patch("app.services.inactivity_service._driver_ids_with_active_trips", new_callable=AsyncMock, return_value=set()),
        patch("app.services.inactivity_service.push_driver_inactivity_check", new_callable=AsyncMock, return_value=True) as mock_push,
        patch("app.services.inactivity_service.set_availability", new_callable=AsyncMock) as mock_set_avail,
    ):
        result = await inactivity_service.check_and_notify_inactive_drivers()

        assert result["status"] == "ok"
        assert result["notified"] == 1
        assert result["autoOffline"] == 1

        # Only driver 1 received notification
        mock_push.assert_awaited_once_with(str(driver1_id))

        # Driver 3 was set to offline
        mock_set_avail.assert_awaited_once_with(str(driver_auto_offline_id), "offline")
