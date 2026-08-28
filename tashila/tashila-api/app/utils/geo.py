import math
from typing import Tuple

R = 6371.0


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Great-circle distance between two WGS84 points in kilometers."""
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lng2 - lng1)

    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


def estimate_minutes(distance_km: float, avg_speed_kmh: float = 35) -> int:
    if distance_km <= 0:
        return 0
    return max(1, math.ceil(distance_km / avg_speed_kmh * 60))


async def get_route_distance_and_duration(lat1: float, lng1: float, lat2: float, lng2: float) -> tuple[float, float]:
    """
    Get actual driving distance (in km) and duration (in minutes) between two points using OSRM.
    Falls back to haversine calculation with a 1.3 multiplier if OSRM fails.
    """
    import httpx
    import logging
    logger = logging.getLogger(__name__)

    url = f"https://router.project-osrm.org/route/v1/driving/{lng1},{lat1};{lng2},{lat2}?overview=false"
    try:
        async with httpx.AsyncClient(timeout=3.0) as client:
            headers = {"User-Agent": "TashilaApp/1.0 (contact: admin@tashila.com)"}
            response = await client.get(url, headers=headers)
            if response.status_code == 200:
                data = response.json()
                if data.get("code") == "Ok" and data.get("routes"):
                    route = data["routes"][0]
                    distance_meters = route.get("distance", 0.0)
                    duration_seconds = route.get("duration", 0.0)
                    
                    distance_km = distance_meters / 1000.0
                    duration_minutes = max(1.0, math.ceil(duration_seconds / 60.0))
                    return distance_km, duration_minutes
    except Exception as e:
        logger.warning("OSRM routing failed: %s. Falling back to haversine estimation.", e)
        
    # Fallback to straight-line distance * routing correction factor (1.3)
    raw_dist = haversine_km(lat1, lng1, lat2, lng2)
    distance_km = raw_dist * 1.3
    duration_minutes = float(estimate_minutes(distance_km))
    return distance_km, duration_minutes



def bounding_box(
    lat: float,
    lng: float,
    radius_km: float,
) -> Tuple[float, float, float, float]:
    """Return (min_lat, max_lat, min_lng, max_lng) for a square bounding box."""
    lat_delta = radius_km / 111.0
    lng_delta = radius_km / (111.0 * max(math.cos(math.radians(lat)), 1e-6))
    return (
        lat - lat_delta,
        lat + lat_delta,
        lng - lng_delta,
        lng + lng_delta,
    )
