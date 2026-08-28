import asyncio
import os
import sys
from bson import ObjectId

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

async def main():
    sys.stdout.reconfigure(encoding='utf-8')
    from app.core.database import connect_db, get_database, close_db
    await connect_db()
    db = get_database()
    
    print("--- Trip Count by Status ---")
    pipeline = [
        {"$group": {"_id": "$status", "count": {"$sum": 1}}}
    ]
    async for row in db.trips.aggregate(pipeline):
        print(f"Status: {row['_id']}, Count: {row['count']}")
        
    print("\n--- Trips with driverId ---")
    cursor = db.trips.find({"driverId": {"$ne": None}})
    count = 0
    async for t in cursor:
        count += 1
        d_id = t.get("driverId")
        print(f"Trip ID: {t['_id']}, status: {t.get('status')}, driverId: {repr(d_id)} (type: {type(d_id)})")
        if count >= 10:
            break
            
    print(f"\nTotal trips with driverId non-None checked: {count}")
    await close_db()

if __name__ == "__main__":
    asyncio.run(main())
