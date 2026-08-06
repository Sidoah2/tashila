import 'dart:math' as math;

/// Great-circle distance between two WGS84 points in kilometers.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  double toRad(double deg) => deg * math.pi / 180;
  final dLat = toRad(lat2 - lat1);
  final dLng = toRad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRad(lat1)) *
          math.cos(toRad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

int estimateMinutes(double distanceKm, {double avgSpeedKmh = 35}) {
  if (distanceKm <= 0) return 0;
  return (distanceKm / avgSpeedKmh * 60).round().clamp(1, 9999);
}

double routeDistanceKm({
  required double pickupLat,
  required double pickupLng,
  required double dropoffLat,
  required double dropoffLng,
  double? apiDistanceKm,
}) {
  final fromApi = apiDistanceKm ?? 0;
  if (fromApi > 0) return fromApi;
  if (pickupLat == 0 && pickupLng == 0) return 0;
  if (dropoffLat == 0 && dropoffLng == 0) return 0;
  return double.parse(
    haversineKm(pickupLat, pickupLng, dropoffLat, dropoffLng).toStringAsFixed(1),
  );
}
