#!/usr/bin/env python3
"""Seed default pricing rules. Run: railway run python scripts/seed_pricing.py"""

import asyncio
import os
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

DEFAULT_PRICING = [
    {
        "truckType": "single_cabin",
        "baseFareDzd": 2000,
        "pricePerKmDzd": 80,
        "label": "Single Cabin Truck",
    },
    {
        "truckType": "double_cabin",
        "baseFareDzd": 3000,
        "pricePerKmDzd": 95,
        "label": "Double Cabin Truck",
    },
]

REMOVED_TRUCK_TYPES = ["semi_truck", "full_truck"]


async def main() -> None:
    from app.core.database import close_db, connect_db, get_database

    await connect_db()
    db = get_database()
    now = datetime.now(timezone.utc)

    for truck_type in REMOVED_TRUCK_TYPES:
        result = await db.pricing.delete_one({"truckType": truck_type})
        if result.deleted_count:
            print(f"Removed: {truck_type}")

    for rule in DEFAULT_PRICING:
        truck_type = rule["truckType"]
        await db.pricing.update_one(
            {"truckType": truck_type},
            {
                "$setOnInsert": {
                    "truckType": truck_type,
                    "label": rule["label"],
                    "baseFareDzd": rule["baseFareDzd"],
                    "pricePerKmDzd": rule["pricePerKmDzd"],
                    "updatedAt": now,
                },
            },
            upsert=True,
        )
        print(f"Seeded: {truck_type}")

    await close_db()


if __name__ == "__main__":
    asyncio.run(main())
