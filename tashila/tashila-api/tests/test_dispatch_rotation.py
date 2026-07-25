"""Dispatch rotation: reject/timeout advances to next candidate."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch

import pytest

from app.services import dispatch_service


@pytest.mark.asyncio
async def test_signal_dispatch_wake_does_not_raise() -> None:
    with (
        patch(
            "app.services.dispatch_service.publish",
            new_callable=AsyncMock,
        ) as publish_mock,
        patch(
            "app.services.dispatch_service.push_dispatch_wake",
            new_callable=AsyncMock,
        ) as push_mock,
    ):
        await dispatch_service.signal_dispatch_wake("trip-1")
        publish_mock.assert_awaited_once_with("dispatch:wake", {"tripId": "trip-1"})
        push_mock.assert_awaited_once_with("trip-1")


@pytest.mark.asyncio
async def test_advance_after_reject_calls_advance_offer_for_active_offer() -> None:
    with (
        patch(
            "app.services.dispatch_service.get_trip_offer",
            new_callable=AsyncMock,
            return_value={"driverId": "d1"},
        ),
        patch(
            "app.services.dispatch_service.advance_offer",
            new_callable=AsyncMock,
        ) as advance_mock,
        patch(
            "app.services.dispatch_service.signal_dispatch_wake",
            new_callable=AsyncMock,
        ) as wake_mock,
    ):
        await dispatch_service.advance_after_reject("trip-1", "d1")
        advance_mock.assert_awaited_once_with("trip-1", "reject")
        wake_mock.assert_not_awaited()


@pytest.mark.asyncio
async def test_advance_after_reject_idempotent_when_offer_cleared() -> None:
    with (
        patch(
            "app.services.dispatch_service.get_trip_offer",
            new_callable=AsyncMock,
            return_value=None,
        ),
        patch(
            "app.services.dispatch_service.advance_offer",
            new_callable=AsyncMock,
        ) as advance_mock,
        patch(
            "app.services.dispatch_service.signal_dispatch_wake",
            new_callable=AsyncMock,
        ) as wake_mock,
    ):
        await dispatch_service.advance_after_reject("trip-1", "d1")
        advance_mock.assert_not_awaited()
        wake_mock.assert_awaited_once_with("trip-1")


@pytest.mark.asyncio
async def test_advance_offer_wakes_dispatch() -> None:
    with (
        patch(
            "app.services.dispatch_service.get_trip_offer",
            new_callable=AsyncMock,
            return_value={"driverId": "d1", "expiresAt": "2026-01-01T00:00:00Z"},
        ),
        patch(
            "app.services.dispatch_service.emit_offer_expired",
            new_callable=AsyncMock,
        ),
        patch(
            "app.services.dispatch_service.clear_trip_offer",
            new_callable=AsyncMock,
        ),
        patch(
            "app.services.dispatch_service.signal_dispatch_wake",
            new_callable=AsyncMock,
        ) as wake_mock,
    ):
        await dispatch_service.advance_offer("trip-1", "reject")
        wake_mock.assert_awaited_once_with("trip-1")


@pytest.mark.asyncio
async def test_dispatch_worker_offers_second_driver_after_reject() -> None:
    trip_id = "trip-rot"
    drivers = [{"id": "d1"}, {"id": "d2"}]
    offer_calls: list[str] = []
    trip_state = {"status": "requested"}

    async def fake_offer(trip, driver, *, candidate_index, generation):
        offer_calls.append(driver["id"])
        return datetime.now(timezone.utc) + timedelta(seconds=30)

    async def fake_wait(t_id, expires_at):
        if offer_calls[-1] == "d1":
            return "reject"
        trip_state["status"] = "accepted"
        return "accepted"

    async def get_trip(_t_id):
        return {"id": trip_id, "status": trip_state["status"]}

    with (
        patch(
            "app.services.dispatch_service.trip_service.get_trip_by_id",
            side_effect=get_trip,
        ),
        patch(
            "app.services.dispatch_service.trip_service.trip_with_client",
            side_effect=get_trip,
        ),
        patch(
            "app.services.dispatch_service.find_dispatch_candidates",
            new_callable=AsyncMock,
            return_value=drivers,
        ),
        patch(
            "app.services.dispatch_service.is_trip_rejected_by_driver",
            new_callable=AsyncMock,
            return_value=False,
        ),
        patch(
            "app.services.dispatch_service.offer_to_driver",
            side_effect=fake_offer,
        ),
        patch(
            "app.services.dispatch_service._wait_offer_window",
            side_effect=fake_wait,
        ),
        patch(
            "app.services.dispatch_service.get_trip_offer",
            new_callable=AsyncMock,
            return_value={"driverId": "d1"},
        ),
        patch(
            "app.services.dispatch_service.advance_offer",
            new_callable=AsyncMock,
        ),
        patch(
            "app.services.dispatch_service.clear_trip_offer",
            new_callable=AsyncMock,
        ),
        patch(
            "app.services.dispatch_service.release_dispatch_lock",
            new_callable=AsyncMock,
        ),
        patch(
            "app.services.dispatch_service.fail_trip_no_drivers",
            new_callable=AsyncMock,
        ) as fail_mock,
    ):
        await dispatch_service._dispatch_worker(
            {"id": trip_id, "status": "requested"},
            "lock-token",
        )

    assert offer_calls == ["d1", "d2"]
    fail_mock.assert_not_awaited()


@pytest.mark.asyncio
async def test_dispatch_worker_fail_when_all_candidates_exhausted() -> None:
    trip_id = "trip-none"
    drivers = [{"id": "d1"}]
    trip_doc = {"id": trip_id, "status": "requested"}

    with (
        patch(
            "app.services.dispatch_service.trip_service.get_trip_by_id",
            new_callable=AsyncMock,
            return_value=trip_doc,
        ),
        patch(
            "app.services.dispatch_service.trip_service.trip_with_client",
            new_callable=AsyncMock,
            return_value=trip_doc,
        ),
        patch(
            "app.services.dispatch_service.find_dispatch_candidates",
            new_callable=AsyncMock,
            return_value=drivers,
        ),
        patch(
            "app.services.dispatch_service.is_trip_rejected_by_driver",
            new_callable=AsyncMock,
            return_value=False,
        ),
        patch(
            "app.services.dispatch_service.offer_to_driver",
            new_callable=AsyncMock,
            return_value=datetime.now(timezone.utc) + timedelta(seconds=30),
        ),
        patch(
            "app.services.dispatch_service._wait_offer_window",
            new_callable=AsyncMock,
            return_value="reject",
        ),
        patch(
            "app.services.dispatch_service.get_trip_offer",
            new_callable=AsyncMock,
            return_value={"driverId": "d1"},
        ),
        patch(
            "app.services.dispatch_service.advance_offer",
            new_callable=AsyncMock,
        ),
        patch(
            "app.services.dispatch_service.clear_trip_offer",
            new_callable=AsyncMock,
        ),
        patch(
            "app.services.dispatch_service.release_dispatch_lock",
            new_callable=AsyncMock,
        ),
        patch(
            "app.services.dispatch_service.fail_trip_no_drivers",
            new_callable=AsyncMock,
        ) as fail_mock,
    ):
        await dispatch_service._dispatch_worker(trip_doc, "lock-token")

    fail_mock.assert_awaited_once_with(trip_id)


@pytest.mark.asyncio
async def test_dispatch_worker_continues_after_candidate_exception() -> None:
    trip_id = "trip-err"
    drivers = [{"id": "d1"}, {"id": "d2"}]
    offer_calls: list[str] = []
    trip_state = {"status": "requested"}

    async def get_trip(_t_id):
        return {"id": trip_id, "status": trip_state["status"]}

    async def flaky_offer(trip, driver, *, candidate_index, generation):
        if driver["id"] == "d1":
            raise RuntimeError("simulated offer failure")
        offer_calls.append(driver["id"])
        return datetime.now(timezone.utc) + timedelta(seconds=30)

    async def fake_wait(_t_id, _expires_at):
        trip_state["status"] = "accepted"
        return "accepted"

    with (
        patch(
            "app.services.dispatch_service.trip_service.get_trip_by_id",
            side_effect=get_trip,
        ),
        patch(
            "app.services.dispatch_service.trip_service.trip_with_client",
            side_effect=get_trip,
        ),
        patch(
            "app.services.dispatch_service.find_dispatch_candidates",
            new_callable=AsyncMock,
            return_value=drivers,
        ),
        patch(
            "app.services.dispatch_service.is_trip_rejected_by_driver",
            new_callable=AsyncMock,
            return_value=False,
        ),
        patch(
            "app.services.dispatch_service.offer_to_driver",
            side_effect=flaky_offer,
        ),
        patch(
            "app.services.dispatch_service._wait_offer_window",
            side_effect=fake_wait,
        ),
        patch(
            "app.services.dispatch_service.get_trip_offer",
            new_callable=AsyncMock,
            return_value=None,
        ),
        patch(
            "app.services.dispatch_service.advance_offer",
            new_callable=AsyncMock,
        ),
        patch(
            "app.services.dispatch_service.clear_trip_offer",
            new_callable=AsyncMock,
        ),
        patch(
            "app.services.dispatch_service.release_dispatch_lock",
            new_callable=AsyncMock,
        ),
        patch(
            "app.services.dispatch_service.fail_trip_no_drivers",
            new_callable=AsyncMock,
        ) as fail_mock,
    ):
        await dispatch_service._dispatch_worker(
            {"id": trip_id, "status": "requested"},
            "lock-token",
        )

    assert offer_calls == ["d2"]
    fail_mock.assert_not_awaited()
