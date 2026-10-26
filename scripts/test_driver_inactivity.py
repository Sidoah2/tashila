#!/usr/bin/env python3
import os
import sys

# Ensure cwd is tashila-api so .env is loaded
api_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tashila", "tashila-api")
os.chdir(api_dir)
sys.path.insert(0, api_dir)

# Run the inactivity test script
script_path = os.path.join(api_dir, "scripts", "test_driver_inactivity.py")
with open(script_path, "r", encoding="utf-8") as f:
    code = compile(f.read(), script_path, "exec")
    exec(code)
