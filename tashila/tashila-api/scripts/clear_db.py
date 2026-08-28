#!/usr/bin/env python3
"""Clear database collections. Run: python scripts/clear_db.py"""

import asyncio
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


async def main() -> None:
    from app.core.database import close_db, connect_db, get_database

    from app.core.config import settings

    force = os.environ.get("FORCE_CLEAR") == "true"
    
    print(f"Target Database URI: {settings.mongo_uri}")
    print(f"Target Database Name: {settings.mongo_db_name}")
    print("\nWARNING: This will delete transactional and user data (users, drivers, trips) from your database!")
    if not force:
        confirm = input("Are you sure you want to proceed? (yes/no): ").strip().lower()
        if confirm != "yes":
            print("Aborted.")
            return

    await connect_db()
    db = get_database()

    # Clear users, drivers, and trips by default
    collections = ["users", "drivers", "trips"]
    
    # Check if they also want to clear pricing/admin_users
    clear_system = os.environ.get("CLEAR_SYSTEM") == "true"
    if not force:
        clear_all = input("Do you also want to clear system collections (pricing, admin_users)? (yes/no): ").strip().lower()
        if clear_all == "yes":
            clear_system = True

    if clear_system:
        collections.extend(["pricing", "admin_users"])

    print("\nStarting database clear...")
    for col in collections:
        res = await db[col].delete_many({})
        print(f"Cleared '{col}' collection: deleted {res.deleted_count} documents.")

    await close_db()
    print("\nDatabase cleared successfully.")


if __name__ == "__main__":
    asyncio.run(main())
