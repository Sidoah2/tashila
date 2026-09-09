import pytest
from unittest.mock import AsyncMock, patch
from bson import ObjectId

from app.services.auth_service import (
    _clean_phone,
    is_test_phone,
    _get_test_otp_codes,
    send_otp,
    verify_otp,
)


def test_clean_and_test_phone_matching():
    # Test Algerian local formats with spaces & without spaces
    p1 = "06 11 22 33 44"
    p2 = "07 11 22 33 44"
    assert is_test_phone(p1) is True
    assert is_test_phone(p2) is True
    assert _clean_phone(p1) == "+213611223344"
    assert _clean_phone(p2) == "+213711223344"

    # International formats
    assert is_test_phone("+213611223344") is True
    assert is_test_phone("+213711223344") is True
    assert is_test_phone("+213 6 11 22 33 44") is True
    assert is_test_phone("+213 7 11 22 33 44") is True
    assert is_test_phone("611223344") is True
    assert is_test_phone("711223344") is True

    # Real phone number should not match
    assert is_test_phone("+213555001122") is False
    assert is_test_phone("0555001122") is False

    # Check OTP codes
    test_codes = _get_test_otp_codes()
    assert "1111" in test_codes
    assert "1234" in test_codes


@pytest.mark.asyncio
async def test_send_otp_test_phone_bypasses_external_sms():
    with patch("app.services.auth_service.store_otp", new_callable=AsyncMock) as mock_store:
        res = await send_otp("06 11 22 33 44", "client")
        assert res["expiresIn"] == 3600
        mock_store.assert_called_once()
        args = mock_store.call_args[0]
        assert args[0] == "+213611223344"
        assert args[1] == "client"
        assert args[2] == "1111"


@pytest.mark.asyncio
async def test_verify_otp_client_test_account():
    fake_user_id = ObjectId()
    fake_collection = AsyncMock()
    fake_collection.find_one = AsyncMock(return_value=None)
    fake_insert_res = AsyncMock()
    fake_insert_res.inserted_id = fake_user_id
    fake_collection.insert_one = AsyncMock(return_value=fake_insert_res)

    with patch("app.services.auth_service.get_database", return_value={"users": fake_collection, "drivers": fake_collection}):
        # Verify with 1234
        res = await verify_otp("06 11 22 33 44", "1234", "client")
        assert "accessToken" in res
        assert "refreshToken" in res
        assert res["user"]["phone"] == "+213611223344"
        assert res["user"]["profileComplete"] is True

        # Verify insert called with complete profile
        fake_collection.insert_one.assert_called_once()
        inserted = fake_collection.insert_one.call_args[0][0]
        assert inserted["name"] == "Test Client"
        assert inserted["profileComplete"] is True
        assert inserted["status"] == "active"


@pytest.mark.asyncio
async def test_verify_otp_driver_test_account():
    fake_driver_id = ObjectId()
    fake_collection = AsyncMock()
    fake_collection.find_one = AsyncMock(return_value=None)
    fake_insert_res = AsyncMock()
    fake_insert_res.inserted_id = fake_driver_id
    fake_collection.insert_one = AsyncMock(return_value=fake_insert_res)

    with patch("app.services.auth_service.get_database", return_value={"users": fake_collection, "drivers": fake_collection}):
        # Verify with 1111
        res = await verify_otp("07 11 22 33 44", "1111", "driver")
        assert "accessToken" in res
        assert "refreshToken" in res
        assert res["user"]["phone"] == "+213711223344"
        assert res["user"]["profileComplete"] is True

        fake_collection.insert_one.assert_called_once()
        inserted = fake_collection.insert_one.call_args[0][0]
        assert inserted["name"] == "Test Driver"
        assert inserted["approvalStatus"] == "approved"
        assert inserted["profileComplete"] is True
        assert "drivingLicense" in inserted["documents"]
        assert inserted["documents"]["drivingLicense"]["status"] == "approved"
