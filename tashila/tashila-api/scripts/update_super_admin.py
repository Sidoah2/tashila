import asyncio, os, sys
sys.path.insert(0, '.')
async def main():
    from app.core.database import connect_db, get_database
    await connect_db()
    db = get_database()
    result = await db['admin_users'].update_many({}, {"$set": {"role": "super_admin"}})
    print(f'Updated {result.modified_count} admin account(s) to super_admin')
asyncio.run(main())
