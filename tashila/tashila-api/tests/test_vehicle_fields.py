"""Vehicle matricule, color, and model in trip/admin payloads."""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest

from app.models.admin import AdminDriverCreate
from app.services import admin_service, trip_service
from app.socket import client_handlers


def test_driver_notify_payload_includes_vehicle_fields() -> None:
    driver = {
        "id": "d1",
        "name": "Driver One",
        "phone": "+213555000111",
        "truckType": "single_cabin",
        "rating": 4.5,
        "vehiclePlate": "12345 116 35",
        "vehicleColor": "White",
        "vehicleModel": "Toyota Hilux",
    }
    payload = client_handlers._driver_notify_payload(driver)

    assert payload["vehiclePlate"] == "12345 116 35"
    assert payload["vehicleColor"] == "White"
    assert payload["vehicleModel"] == "Toyota Hilux"


@pytest.mark.asyncio
async def test_get_driver_info_includes_vehicle_fields() -> None:
    driver_doc = {
        "_id": "507f1f77bcf86cd799439011",
        "id": "507f1f77bcf86cd799439011",
        "phone": "+213555000111",
        "name": "Driver One",
        "truckType": "single_cabin",
        "vehiclePlate": "12345 116 35",
        "vehicleColor": "Blue",
        "vehicleModel": "Isuzu D-Max",
    }

    with patch(
        "app.services.trip_service._find_driver",
        new=AsyncMock(return_value=driver_doc),
    ):
        info = await trip_service._get_driver_info("507f1f77bcf86cd799439011")

    assert info is not None
    assert info["vehiclePlate"] == "12345 116 35"
    assert info["vehicleColor"] == "Blue"
    assert info["vehicleModel"] == "Isuzu D-Max"


@pytest.mark.asyncio
async def test_admin_create_driver_persists_vehicle_fields() -> None:
    body = AdminDriverCreate(
        phone="+213555999888",
        name="Admin Driver",
        truckType="single_cabin",
        vehiclePlate="99999 116 35",
        vehicleColor="Red",
        vehicleModel="Renault Master",
    )
    inserted: dict = {}

    async def fake_insert_one(doc):
        inserted.update(doc)
        class Result:
            inserted_id = "507f1f77bcf86cd799439099"

        return Result()

    mock_collection = AsyncMock()
    mock_collection.find_one = AsyncMock(return_value=None)
    mock_collection.insert_one = fake_insert_one

    mock_db = {admin_service.DRIVERS_COLLECTION: mock_collection}

    with patch("app.services.admin_service.get_database", return_value=mock_db):
        result = await admin_service.admin_create_driver(body)

    assert inserted["vehiclePlate"] == "99999 116 35"
    assert inserted["vehicleColor"] == "Red"
    assert inserted["vehicleModel"] == "Renault Master"
    assert result["vehiclePlate"] == "99999 116 35"
    assert result["vehicleColor"] == "Red"
    assert result["vehicleModel"] == "Renault Master"
