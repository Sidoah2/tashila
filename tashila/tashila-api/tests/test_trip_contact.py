"""Trip contact fields exposed to drivers (client phone on offers/active trip)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch

import pytest

from app.services import dispatch_service, trip_service


@pytest.mark.asyncio
async def test_offer_socket_payload_includes_client_phone() -> None:
    trip = {
        "id": "trip-1",
        "client": {"name": "Client One", "phone": "+213555000111"},
        "pickup": {"lat": 36.7, "lng": 3.1},
        "dropoff": {"lat": 36.8, "lng": 3.2},
        "fare": 1500,
    }
    driver = {"id": "d1", "distanceMeters": 1200}
    expires = datetime.now(timezone.utc) + timedelta(seconds=30)

    payload = dispatch_service._offer_socket_payload(
        trip,
        driver,
        expires_at=expires,
        generation=1,
    )

    assert payload["client"]["name"] == "Client One"
    assert payload["client"]["phone"] == "+213555000111"


@pytest.mark.asyncio
async def test_build_current_offer_includes_client_phone() -> None:
    trip_id = "trip-offer"
    trip = {
        "id": trip_id,
        "clientId": "client-1",
        "status": "requested",
        "pickup": {"lat": 36.7, "lng": 3.1},
        "dropoff": {"lat": 36.8, "lng": 3.2},
        "fare": 2000,
        "distanceKm": 5.0,
        "estimatedMinutes": 12,
        "createdAt": datetime.now(timezone.utc),
    }
    offer = {
        "driverId": "d1",
        "expiresAt": (datetime.now(timezone.utc) + timedelta(seconds=30)).isoformat(),
        "generation": 2,
    }

    with (
        patch(
            "app.services.dispatch_service.get_driver_offer_trip_id",
            new_callable=AsyncMock,
            return_value=trip_id,
        ),
        patch(
            "app.services.dispatch_service.trip_service.get_trip_by_id",
            new_callable=AsyncMock,
            return_value=trip,
        ),
        patch(
            "app.services.dispatch_service.get_trip_offer",
            new_callable=AsyncMock,
            return_value=offer,
        ),
        patch(
            "app.services.trip_service._get_client_info",
            new_callable=AsyncMock,
            return_value={
                "id": "client-1",
                "name": "Client Two",
                "phone": "+213555000222",
            },
        ),
    ):
        result = await dispatch_service.build_current_offer_for_driver("d1")

    assert result is not None
    assert result["clientName"] == "Client Two"
    assert result["clientPhone"] == "+213555000222"
    assert result["client"]["phone"] == "+213555000222"


@pytest.mark.asyncio
async def test_get_active_trip_for_driver_includes_client() -> None:
    trip_doc = {
        "_id": "abc123",
        "clientId": "client-9",
        "driverId": "d9",
        "status": "accepted",
        "fare": 1800,
    }

    with (
        patch(
            "app.services.trip_service.get_database",
        ) as db_mock,
        patch(
            "app.services.trip_service._get_client_info",
            new_callable=AsyncMock,
            return_value={
                "id": "client-9",
                "name": "Active Client",
                "phone": "+213555000999",
            },
        ),
    ):
        collection = AsyncMock()
        collection.find_one = AsyncMock(return_value=trip_doc)
        db_mock.return_value.__getitem__.return_value = collection

        result = await trip_service.get_active_trip_for_driver("d9")

    assert result is not None
    assert result["client"]["name"] == "Active Client"
    assert result["client"]["phone"] == "+213555000999"
