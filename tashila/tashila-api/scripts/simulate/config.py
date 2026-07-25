import os

BASE_URL = os.environ.get("SIM_BASE_URL", "https://tashila-api-production.up.railway.app")
# Socket.IO is served at the default /socket.io path (wrapped ASGI app)
WS_URL   = BASE_URL

SIM_SECRET = os.environ.get("SIM_SECRET", "sim-secret-2024")

NUM_CLIENTS = int(os.environ.get("SIM_NUM_CLIENTS", "100"))
NUM_DRIVERS = int(os.environ.get("SIM_NUM_DRIVERS", "30"))
TRIP_CYCLES_PER_CLIENT = int(os.environ.get("SIM_TRIP_CYCLES", "3"))

DRIVER_OFFER_TIMEOUT  = 40    # seconds: how long a driver waits for a trip offer
TRIP_COMPLETE_TIMEOUT = 120   # seconds: max wait for a trip to reach completed
INTER_TRIP_DELAY_MIN  = 1
INTER_TRIP_DELAY_MAX  = 4
ADMIN_POLL_INTERVAL   = 5     # seconds between admin approval polls

TRUCK_TYPES = ["single_cabin", "double_cabin"]

# Algiers area bounding box
LAT_MIN, LAT_MAX = 36.65, 36.82
LNG_MIN, LNG_MAX = 2.95, 3.20

# HTTP client-level timeouts
HTTP_TIMEOUT = 30.0

# Accept/reject ratio for drivers (0.0–1.0 accept rate)
DRIVER_ACCEPT_RATE = 0.85
