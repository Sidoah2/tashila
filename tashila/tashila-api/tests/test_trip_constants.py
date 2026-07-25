"""Unit tests for trip lifecycle constants and helpers."""

from app.services.trip_service import (
    ACTIVE_CLIENT_STATUSES,
    DRIVER_ACTIVE_TRIP_STATUSES,
    VALID_CANCEL_REASONS,
    _normalize_cancel_reason,
)
from app.core.exceptions import ValidationError
import pytest


def test_awaiting_cash_in_active_statuses() -> None:
    assert "awaitingCash" in ACTIVE_CLIENT_STATUSES
    assert "awaitingCash" in DRIVER_ACTIVE_TRIP_STATUSES


def test_normalize_cancel_reason_accepts_keys() -> None:
    assert _normalize_cancel_reason("changed_plans") == "changed_plans"


def test_normalize_cancel_reason_rejects_free_text() -> None:
    with pytest.raises(ValidationError):
        _normalize_cancel_reason("Changed plans")


def test_valid_cancel_reasons_non_empty() -> None:
    assert "other" in VALID_CANCEL_REASONS
