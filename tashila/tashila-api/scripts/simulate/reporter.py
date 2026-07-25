"""Thread-safe simulation statistics reporter."""
from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass, field
from typing import Any


@dataclass
class SimError:
    actor: str
    context: str
    detail: str


@dataclass
class SimStats:
    trips_created: int = 0
    trips_accepted: int = 0
    trips_completed: int = 0
    trips_no_driver: int = 0
    trips_cancelled: int = 0
    offers_received: int = 0
    offers_expired: int = 0
    offer_accept_latencies: list[float] = field(default_factory=list)
    trip_offer_counts: dict[str, int] = field(default_factory=dict)
    accept_conflicts_409: int = 0
    accept_after_expiry_blocked: int = 0
    late_offers_seen: int = 0
    errors: list[SimError] = field(default_factory=list)
    latencies_accept: list[float] = field(default_factory=list)
    latencies_complete: list[float] = field(default_factory=list)


_stats = SimStats()
_lock = asyncio.Lock()
_start_time: float = 0.0


def start_timer() -> None:
    global _start_time
    _start_time = time.time()


async def record_trip_created() -> None:
    async with _lock:
        _stats.trips_created += 1


async def record_trip_accepted(latency: float) -> None:
    async with _lock:
        _stats.trips_accepted += 1
        _stats.latencies_accept.append(latency)


async def record_trip_completed(latency: float) -> None:
    async with _lock:
        _stats.trips_completed += 1
        _stats.latencies_complete.append(latency)


async def record_trip_no_driver() -> None:
    async with _lock:
        _stats.trips_no_driver += 1


async def record_trip_cancelled() -> None:
    async with _lock:
        _stats.trips_cancelled += 1


async def record_offer_received(trip_id: str | None = None) -> None:
    async with _lock:
        _stats.offers_received += 1
        if trip_id:
            _stats.trip_offer_counts[trip_id] = (
                _stats.trip_offer_counts.get(trip_id, 0) + 1
            )


async def record_offer_expired() -> None:
    async with _lock:
        _stats.offers_expired += 1


async def record_offer_accepted(latency: float) -> None:
    async with _lock:
        _stats.offer_accept_latencies.append(latency)


async def record_accept_conflict() -> None:
    async with _lock:
        _stats.accept_conflicts_409 += 1


async def record_accept_after_expiry_blocked() -> None:
    async with _lock:
        _stats.accept_after_expiry_blocked += 1


async def record_late_offer_seen() -> None:
    async with _lock:
        _stats.late_offers_seen += 1


async def record_error(actor: str, context: str, detail: str) -> None:
    async with _lock:
        _stats.errors.append(SimError(actor=actor, context=context, detail=str(detail)[:200]))


def _avg(lst: list[float]) -> str:
    if not lst:
        return "n/a"
    return f"{sum(lst) / len(lst):.1f}s"


def print_report(num_clients: int, num_drivers: int) -> int:
    duration = time.time() - _start_time if _start_time else 0
    completion_rate = (
        f"{100 * _stats.trips_completed / _stats.trips_created:.1f}%"
        if _stats.trips_created
        else "n/a"
    )

    print("\n" + "=" * 60)
    print("  TASHILA SIMULATION REPORT")
    print("=" * 60)
    print(f"  Actors:           {num_clients} clients, {num_drivers} drivers, 1 admin")
    print(f"  Duration:         {duration:.0f}s")
    print()
    print(f"  Trips created:    {_stats.trips_created}")
    print(f"  Trips accepted:   {_stats.trips_accepted}")
    print(f"  Trips completed:  {_stats.trips_completed}")
    print(f"  Completion rate:  {completion_rate}")
    print(f"  No driver found:  {_stats.trips_no_driver}")
    print(f"  Trips cancelled:  {_stats.trips_cancelled}")
    print()
    print(f"  Offers received:  {_stats.offers_received}")
    print(f"  Offers expired:   {_stats.offers_expired}")
    rotations = sum(max(0, c - 1) for c in _stats.trip_offer_counts.values())
    rotated_trips = sum(1 for c in _stats.trip_offer_counts.values() if c > 1)
    print(f"  Offer rotations:  {rotations} ({rotated_trips} trips with 2+ offers)")
    print(f"  Avg offer→accept: {_avg(_stats.offer_accept_latencies)}")
    print(f"  409 conflicts:    {_stats.accept_conflicts_409}")
    print(f"  Expired accepts blocked: {_stats.accept_after_expiry_blocked}")
    print(f"  Late offers seen: {_stats.late_offers_seen}")
    print()
    print(f"  Avg create→accept:    {_avg(_stats.latencies_accept)}")
    print(f"  Avg accept→complete:  {_avg(_stats.latencies_complete)}")
    print()
    error_count = len(_stats.errors)
    print(f"  Errors:           {error_count}")
    if _stats.errors:
        print()
        for i, err in enumerate(_stats.errors[:30]):
            print(f"    [{i+1}] [{err.actor}] {err.context}: {err.detail}")
        if error_count > 30:
            print(f"    ... and {error_count - 30} more")
    print("=" * 60)

    return error_count


def get_error_count() -> int:
    return len(_stats.errors)
