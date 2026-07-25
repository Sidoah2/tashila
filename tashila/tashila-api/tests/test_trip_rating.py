"""Trip rating and pending-rating active-trip lookup."""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest

from app.services import trip_service


@pytest.mark.asyncio
async def test_get_active_trip_for_client_includes_completed_pending_driver_rating() -> None:
    trip_doc = {
        "_id": "507f1f77bcf86cd799439011",
        "clientId": "c1",
        "driverId": "d1",
        "status": "completed",
        "driverRating": None,
        "pickup": {"lat": 36.7, "lng": 3.1, "address": "Pickup Ave"},
        "dropoff": {"lat": 36.8, "lng": 3.2, "address": "Drop St"},
        "fare": 1500,
    }

    mock_collection = AsyncMock()
    mock_collection.find_one = AsyncMock(return_value=trip_doc)
    mock_db = {"trips": mock_collection}

    with (
        patch("app.services.trip_service.get_database", return_value=mock_db),
        patch(
            "app.services.trip_service._get_driver_info",
            new=AsyncMock(return_value={"id": "d1", "name": "Driver One"}),
        ),
    ):
        result = await trip_service.get_active_trip_for_client("c1")

    assert result is not None
    assert result["status"] == "completed"
    assert result["driverRating"] is None
    call_filter = mock_collection.find_one.await_args.args[0]
    assert "$or" in call_filter


@pytest.mark.asyncio
async def test_get_active_trip_for_driver_includes_completed_pending_client_rating() -> None:
    trip_doc = {
        "_id": "507f1f77bcf86cd799439011",
        "clientId": "c1",
        "driverId": "d1",
        "status": "completed",
        "clientRating": None,
        "pickup": {"lat": 36.7, "lng": 3.1, "address": "Pickup Ave"},
        "dropoff": {"lat": 36.8, "lng": 3.2, "address": "Drop St"},
        "fare": 1500,
    }

    mock_collection = AsyncMock()
    mock_collection.find_one = AsyncMock(return_value=trip_doc)
    mock_db = {"trips": mock_collection}

    with (
        patch("app.services.trip_service.get_database", return_value=mock_db),
        patch(
            "app.services.trip_service._get_client_info",
            new=AsyncMock(return_value={"id": "c1", "name": "Client One"}),
        ),
    ):
        result = await trip_service.get_active_trip_for_driver("d1")

    assert result is not None
    assert result["status"] == "completed"
    assert result["clientRating"] is None


@pytest.mark.asyncio
async def test_rate_driver_updates_driver_average() -> None:
    trip_doc = {
        "_id": "507f1f77bcf86cd799439011",
        "clientId": "c1",
        "driverId": "d1",
        "status": "completed",
        "driverRating": None,
    }
    updated_trip = {**trip_doc, "driverRating": 5}

    trips_collection = AsyncMock()
    trips_collection.find_one = AsyncMock(return_value=trip_doc)
    trips_collection.update_one = AsyncMock()
    trips_collection.aggregate = AsyncMock(
        return_value=AsyncMock(to_list=AsyncMock(return_value=[{"avgRating": 4.5}]))
    )

    drivers_collection = AsyncMock()
    drivers_collection.update_one = AsyncMock()

    mock_db = {"trips": trips_collection, "drivers": drivers_collection}

    with (
        patch("app.services.trip_service.get_database", return_value=mock_db),
        patch(
            "app.services.trip_service._find_trip",
            new=AsyncMock(side_effect=[trip_doc, updated_trip]),
        ),
    ):
        result = await trip_service.rate_driver("507f1f77bcf86cd799439011", "c1", 5, "Great")

    assert result["driverRating"] == 5
    drivers_collection.update_one.assert_awaited_once()
