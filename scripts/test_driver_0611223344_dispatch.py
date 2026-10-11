#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path

TARGET_SCRIPT = (
    Path(__file__).resolve().parent.parent
    / "tashila"
    / "tashila-api"
    / "scripts"
    / "test_driver_0611223344_dispatch.py"
)

if not TARGET_SCRIPT.exists():
    print(f"Error: Could not find target script at {TARGET_SCRIPT}")
    sys.exit(1)

ret = subprocess.call([sys.executable, str(TARGET_SCRIPT)] + sys.argv[1:])
sys.exit(ret)
