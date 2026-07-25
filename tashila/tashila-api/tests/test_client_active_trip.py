"""Client active-trip lookup for app resume."""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest

from app.services import trip_service


@pytest.mark.asyncio
async def test_get_active_trip_for_client_includes_driver_and_locations() -> None:
    trip_doc = {
        "_id": "507f1f77bcf86cd799439011",
        "clientId": "c1",
        "driverId": "d1",
        "status": "accepted",
        "pickup": {"lat": 36.7, "lng": 3.1, "address": "Pickup Ave"},
        "dropoff": {"lat": 36.8, "lng": 3.2, "address": "Drop St"},
        "fare": 1500,
    }
    driver_info = {
        "id": "d1",
        "name": "Driver One",
        "phone": "+213555000111",
        "vehiclePlate": "12345 116 35",
        "vehicleColor": "White",
        "vehicleModel": "Toyota Hilux",
    }

    mock_collection = AsyncMock()
    mock_collection.find_one = AsyncMock(return_value=trip_doc)
    mock_db = {"trips": mock_collection}

    with (
        patch("app.services.trip_service.get_database", return_value=mock_db),
        patch(
            "app.services.trip_service._get_driver_info",
            new=AsyncMock(return_value=driver_info),
        ),
    ):
        result = await trip_service.get_active_trip_for_client("c1")

    assert result is not None
    assert result["pickup"]["address"] == "Pickup Ave"
    assert result["dropoff"]["address"] == "Drop St"
    assert result["driver"]["name"] == "Driver One"
    assert result["driver"]["vehicleModel"] == "Toyota Hilux"


@pytest.mark.asyncio
async def test_get_active_trip_for_client_returns_none_when_no_trip() -> None:
    mock_collection = AsyncMock()
    mock_collection.find_one = AsyncMock(return_value=None)
    mock_db = {"trips": mock_collection}

    with patch("app.services.trip_service.get_database", return_value=mock_db):
        result = await trip_service.get_active_trip_for_client("c1")

    assert result is None
