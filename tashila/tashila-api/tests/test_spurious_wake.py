import asyncio
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch
import pytest
from app.services import dispatch_service

@pytest.mark.asyncio
async def test_wait_offer_window_spurious_wake() -> None:
    trip_id = "test-trip-spurious"
    expires_at = datetime.now(timezone.utc) + timedelta(seconds=5)

    # We will simulate:
    # 1. Wake event triggers but offer is still active -> wait continues.
    # 2. Wake event triggers and offer is None -> wait returns "reject".
    
    offer_state = {"active": True}
    
    async def mock_get_trip_offer(t_id):
        if offer_state["active"]:
            return {"driverId": "d1"}
        return None

    with (
        patch(
            "app.services.dispatch_service.trip_service.get_trip_by_id",
            new_callable=AsyncMock,
            return_value={"status": "requested"},
        ),
        patch(
            "app.services.dispatch_service.get_trip_offer",
            side_effect=mock_get_trip_offer,
        ),
    ):
        # Start _wait_offer_window
        wait_task = asyncio.create_task(
            dispatch_service._wait_offer_window(trip_id, expires_at)
        )
        
        # Yield control to let it start waiting
        await asyncio.sleep(0.01)
        
        # Trigger spurious wake
        dispatch_service.notify_dispatch_wake(trip_id)
        
        # Yield control. The task should still be running because get_trip_offer returned an active offer.
        await asyncio.sleep(0.01)
        assert not wait_task.done()
        
        # Now simulate actual reject (offer is cleared)
        offer_state["active"] = False
        dispatch_service.notify_dispatch_wake(trip_id)
        
        # The task should complete now and return "reject"
        result = await wait_task
        assert result == "reject"
