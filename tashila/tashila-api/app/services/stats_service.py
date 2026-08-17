import asyncio
from datetime import datetime, timedelta, timezone
from typing import Any

from app.core.database import get_database

USERS_COLLECTION = "users"
DRIVERS_COLLECTION = "drivers"
TRIPS_COLLECTION = "trips"

ACTIVE_TRIP_STATUSES = (
    "accepted",
    "headingToPickup",
    "inProgress",
    "awaitingCash",
)


def _month_start_utc(now: datetime) -> datetime:
    return now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)


async def _count_active_users() -> int:
    return await get_database()[USERS_COLLECTION].count_documents({"status": "active"})


async def _count_approved_drivers() -> int:
    return await get_database()[DRIVERS_COLLECTION].count_documents(
        {"approvalStatus": "approved"},
    )


async def _trips_by_status() -> dict[str, int]:
    pipeline = [
        {"$group": {"_id": "$status", "count": {"$sum": 1}}},
    ]
    result: dict[str, int] = {}
    async for row in get_database()[TRIPS_COLLECTION].aggregate(pipeline):
        status = row.get("_id")
        if status:
            result[str(status)] = int(row["count"])
    return result


async def _sum_completed_fare(match_extra: dict[str, Any] | None = None) -> float:
    match: dict[str, Any] = {"status": "completed"}
    if match_extra:
        match.update(match_extra)
    pipeline = [
        {"$match": match},
        {"$group": {"_id": None, "total": {"$sum": {"$ifNull": ["$finalFare", "$fare"]}}}},
    ]
    rows = await get_database()[TRIPS_COLLECTION].aggregate(pipeline).to_list(1)
    if not rows:
        return 0.0
    return float(rows[0].get("total") or 0)


async def _count_active_trips() -> int:
    return await get_database()[TRIPS_COLLECTION].count_documents(
        {"status": {"$in": list(ACTIVE_TRIP_STATUSES)}},
    )


async def _count_pending_approvals() -> int:
    return await get_database()[DRIVERS_COLLECTION].count_documents(
        {"approvalStatus": "pending"},
    )


async def _count_online_drivers() -> int:
    return await get_database()[DRIVERS_COLLECTION].count_documents(
        {"approvalStatus": "approved", "availability": "online"},
    )


def _today_start_utc(now: datetime) -> datetime:
    algiers_tz = timezone(timedelta(hours=1))
    local_now = now.astimezone(algiers_tz)
    local_midnight = local_now.replace(hour=0, minute=0, second=0, microsecond=0)
    return local_midnight.astimezone(timezone.utc)


async def _count_completed_trips_since(since: datetime) -> int:
    return await get_database()[TRIPS_COLLECTION].count_documents(
        {"status": "completed", "completedAt": {"$gte": since}},
    )


async def _count_trips_by_status(
    status: str,
    match_extra: dict[str, Any] | None = None,
) -> int:
    match: dict[str, Any] = {"status": status}
    if match_extra:
        match.update(match_extra)
    return await get_database()[TRIPS_COLLECTION].count_documents(match)


async def get_dashboard_kpis(
    *,
    from_date: datetime | None = None,
    to_date: datetime | None = None,
) -> dict[str, Any]:
    now = datetime.now(timezone.utc)
    month_start = _month_start_utc(now)
    today_start = _today_start_utc(now)

    period_match: dict[str, Any] | None = None
    completed_period_match: dict[str, Any] | None = None
    if from_date is not None or to_date is not None:
        period_match = {}
        completed_period_match = {}
        if from_date is not None:
            period_match["createdAt"] = {"$gte": from_date}
            completed_period_match["completedAt"] = {"$gte": from_date}
        if to_date is not None:
            end = to_date.replace(hour=23, minute=59, second=59, microsecond=999999)
            period_match.setdefault("createdAt", {})["$lte"] = end
            completed_period_match.setdefault("completedAt", {})["$lte"] = end

    (
        active_users,
        approved_drivers,
        online_drivers,
        trips_by_status,
        month_revenue,
        all_time_revenue,
        today_revenue,
        today_trips,
        active_trips,
        pending_approvals,
        period_revenue,
        period_completed,
        period_cancelled,
    ) = await asyncio.gather(
        _count_active_users(),
        _count_approved_drivers(),
        _count_online_drivers(),
        _trips_by_status(),
        _sum_completed_fare({"completedAt": {"$gte": month_start}}),
        _sum_completed_fare(),
        _sum_completed_fare({"completedAt": {"$gte": today_start}}),
        _count_completed_trips_since(today_start),
        _count_active_trips(),
        _count_pending_approvals(),
        _sum_completed_fare(completed_period_match) if completed_period_match else _sum_completed_fare(),
        _count_trips_by_status("completed", completed_period_match),
        _count_trips_by_status("cancelled", period_match),
    )

    return {
        "activeUsers": active_users,
        "approvedDrivers": approved_drivers,
        "onlineDrivers": online_drivers,
        "tripsByStatus": trips_by_status,
        "monthRevenue": month_revenue,
        "allTimeRevenue": all_time_revenue,
        "todayRevenue": today_revenue,
        "todayTrips": today_trips,
        "activeTrips": active_trips,
        "pendingApprovals": pending_approvals,
        "periodRevenue": period_revenue,
        "periodCompletedTrips": period_completed,
        "periodCancelledTrips": period_cancelled,
    }


async def get_revenue_chart(
    range_days: int | None = None,
    *,
    from_date: datetime | None = None,
    to_date: datetime | None = None,
) -> dict[str, Any]:
    now = datetime.now(timezone.utc)
    if from_date is not None:
        start_date = from_date
        end = to_date or now
    else:
        days = range_days if range_days is not None else 14
        start_date = now - timedelta(days=days)
        end = now

    pipeline = [
        {
            "$match": {
                "status": "completed",
                "completedAt": {"$gte": start_date, "$lte": end},
            },
        },
        {
            "$group": {
                "_id": {
                    "$dateToString": {
                        "format": "%Y-%m-%d",
                        "date": "$completedAt",
                        "timezone": "+01:00",
                    },
                },
                "revenue": {"$sum": {"$ifNull": ["$finalFare", "$fare"]}},
                "trips": {"$sum": 1},
            },
        },
        {"$sort": {"_id": 1}},
    ]

    by_date: dict[str, dict[str, float | int]] = {}
    async for row in get_database()[TRIPS_COLLECTION].aggregate(pipeline):
        day = row["_id"]
        by_date[day] = {
            "revenue": float(row.get("revenue") or 0),
            "trips": int(row.get("trips") or 0),
        }

    algiers_tz = timezone(timedelta(hours=1))
    local_start = start_date.astimezone(algiers_tz)
    local_end = end.astimezone(algiers_tz)

    labels: list[str] = []
    revenue: list[float] = []
    trips: list[int] = []
    current = local_start.date()
    end_date = local_end.date()
    while current <= end_date:
        key = current.isoformat()
        labels.append(key)
        day_data = by_date.get(key, {"revenue": 0.0, "trips": 0})
        revenue.append(float(day_data["revenue"]))
        trips.append(int(day_data["trips"]))
        current += timedelta(days=1)

    return {"labels": labels, "revenue": revenue, "trips": trips}


async def get_top_drivers(
    limit: int = 10,
    *,
    from_date: datetime | None = None,
    to_date: datetime | None = None,
) -> list[dict[str, Any]]:
    match: dict[str, Any] = {"status": "completed", "driverId": {"$ne": None}}
    if from_date is not None or to_date is not None:
        created_at: dict[str, Any] = {}
        if from_date is not None:
            created_at["$gte"] = from_date
        if to_date is not None:
            created_at["$lte"] = to_date.replace(
                hour=23, minute=59, second=59, microsecond=999999,
            )
        match["createdAt"] = created_at

    pipeline = [
        {"$match": match},
        {
            "$group": {
                "_id": "$driverId",
                "totalEarnedDzd": {"$sum": {"$ifNull": ["$finalFare", "$fare"]}},
                "completedTrips": {"$sum": 1},
            },
        },
        {"$sort": {"totalEarnedDzd": -1}},
        {"$limit": limit},
        {
            "$lookup": {
                "from": DRIVERS_COLLECTION,
                "let": {"driverId": "$_id"},
                "pipeline": [
                    {
                        "$match": {
                            "$expr": {
                                "$eq": [{"$toString": "$_id"}, "$$driverId"],
                            },
                        },
                    },
                    {"$project": {"name": 1, "truckType": 1}},
                ],
                "as": "driver",
            },
        },
    ]

    results: list[dict[str, Any]] = []
    async for row in get_database()[TRIPS_COLLECTION].aggregate(pipeline):
        driver_info = (row.get("driver") or [{}])[0]
        results.append(
            {
                "driverId": row["_id"],
                "name": driver_info.get("name"),
                "truckType": driver_info.get("truckType"),
                "totalEarnedDzd": float(row.get("totalEarnedDzd") or 0),
                "completedTrips": int(row.get("completedTrips") or 0),
            },
        )
    return results


async def _count_drivers_with_pending_documents() -> int:
    pipeline = [
        {
            "$match": {
                "$expr": {
                    "$gt": [
                        {
                            "$size": {
                                "$filter": {
                                    "input": {
                                        "$objectToArray": {"$ifNull": ["$documents", {}]},
                                    },
                                    "as": "doc",
                                    "cond": {"$eq": ["$$doc.v.status", "pending"]},
                                },
                            },
                        },
                        0,
                    ],
                },
            },
        },
        {"$count": "count"},
    ]
    rows = await get_database()[DRIVERS_COLLECTION].aggregate(pipeline).to_list(1)
    return int(rows[0]["count"]) if rows else 0


async def get_pending_approvals_count() -> dict[str, int]:
    pending_drivers, pending_documents = await asyncio.gather(
        _count_pending_approvals(),
        _count_drivers_with_pending_documents(),
    )
    return {
        "pendingDrivers": pending_drivers,
        "pendingDocuments": pending_documents,
    }
