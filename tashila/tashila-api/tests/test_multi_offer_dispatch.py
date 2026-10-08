"""Test for multi-offer dispatch: rejecting one trip does not clear other trips for other drivers."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch

import pytest

from app.services import dispatch_service, trip_service


@pytest.mark.asyncio
async def test_driver_retains_unaccepted_offer_when_other_trip_accepted() -> None:
    """When Driver 1 rejects Trip 1 and accepts Trip 2, Driver 2 must still receive Trip 1."""
    d1 = "driver-1"
    d2 = "driver-2"
    t1 = "trip-1"
    t2 = "trip-2"

    future_exp = (datetime.now(timezone.utc) + timedelta(seconds=120)).isoformat()

    trip1_doc = {
        "id": t1,
        "_id": t1,
        "status": "requested",
        "clientId": "client-1",
        "pickup": {"lat": 36.7, "lng": 3.1, "address": "Place A"},
        "dropoff": {"lat": 36.8, "lng": 3.2, "address": "Place B"},
        "fare": 1500,
        "truckType": "single_cabin",
    }
    trip2_doc = {
        "id": t2,
        "_id": t2,
        "status": "accepted",  # Accepted by d1
        "driverId": d1,
        "clientId": "client-2",
        "pickup": {"lat": 36.75, "lng": 3.15, "address": "Place C"},
        "dropoff": {"lat": 36.85, "lng": 3.25, "address": "Place D"},
        "fare": 2000,
        "truckType": "single_cabin",
    }

    offer1 = {
        "driverIds": [d2],  # d1 rejected t1, d2 remains
        "expiresAt": future_exp,
        "generation": 1,
    }

    async def mock_get_trip_by_id(trip_id: str):
        if trip_id == t1:
            return trip1_doc
        if trip_id == t2:
            return trip2_doc
        return None

    with (
        patch("app.services.dispatch_service.get_driver_offer_trip_ids", new=AsyncMock(return_value=[t1])),
        patch("app.services.dispatch_service.is_trip_rejected_by_driver", new=AsyncMock(return_value=False)),
        patch("app.services.dispatch_service.trip_service.get_trip_by_id", side_effect=mock_get_trip_by_id),
        patch("app.services.dispatch_service.get_trip_offer", new=AsyncMock(return_value=offer1)),
        patch(
            "app.services.trip_service._get_client_info",
            new=AsyncMock(return_value={"id": "client-1", "name": "Client 1", "phone": "0555112233"}),
        ),
    ):
        offers = await dispatch_service.build_all_current_offers_for_driver(d2)
        assert len(offers) == 1
        assert offers[0]["id"] == t1
        assert offers[0]["fare"] == 1500

        single_offer = await dispatch_service.build_current_offer_for_driver(d2)
        assert single_offer is not None
        assert single_offer["id"] == t1
