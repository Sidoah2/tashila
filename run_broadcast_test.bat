@echo off
echo ========================================================
echo   Running Tashila Broadcast Dispatch Verification Script
echo ========================================================
cd /d "%~dp0tashila\tashila-api"
python scripts\test_broadcast_dispatch_flow.py %*
pause
