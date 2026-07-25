#!/usr/bin/env python3
"""Seed or update an admin account. Run: railway run python scripts/seed_admin.py"""

import asyncio
import os
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


async def main() -> None:
    from app.core.database import close_db, connect_db, get_database
    from app.core.security import hash_password

    email = os.environ.get("ADMIN_EMAIL") or input("Admin email: ")
    password = os.environ.get("ADMIN_PASSWORD") or input("Admin password: ")
    name = os.environ.get("ADMIN_NAME", "Super Admin")

    await connect_db()
    db = get_database()
    now = datetime.now(timezone.utc)

    existing = await db.admin_users.find_one({"email": email})
    if existing:
        print(f"Admin {email} already exists. Updating password...")
        await db.admin_users.update_one(
            {"email": email},
            {"$set": {"passwordHash": hash_password(password), "updatedAt": now}},
        )
    else:
        await db.admin_users.insert_one(
            {
                "email": email,
                "passwordHash": hash_password(password),
                "name": name,
                "role": "admin",
                "createdAt": now,
            },
        )
        print(f"Admin {email} created successfully.")

    await close_db()


if __name__ == "__main__":
    asyncio.run(main())
