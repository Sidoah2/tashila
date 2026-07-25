import 'dart:math' as math;

/// Fixed neighborhoods for Tamanrasset region (mirrors tashila-api/data/neighborhoods.json).
class NeighborhoodPick {
  const NeighborhoodPick({
    required this.titleEn,
    required this.titleAr,
    required this.lat,
    required this.lng,
    this.supported = true,
  });

  final String titleEn;
  final String titleAr;
  final double lat;
  final double lng;

  /// When `false`, selecting this area shows [kServiceNotInAreaMessageKey] (localized).
  final bool supported;

  /// English label kept for callers that still reference [title].
  String get title => titleEn;

  /// Localized display label for the current app language.
  String labelForLocale(String languageCode) {
    if (languageCode == 'ar') return titleAr;
    return titleEn;
  }

  static const List<NeighborhoodPick> all = [
    NeighborhoodPick(
      titleEn: 'Tamanrasset Center',
      titleAr: 'وسط تمنراست',
      lat: 22.785,
      lng: 5.523,
    ),
    NeighborhoodPick(
      titleEn: 'Tamanrasset Airport',
      titleAr: 'مطار تمنراست',
      lat: 22.812,
      lng: 5.451,
    ),
    NeighborhoodPick(
      titleEn: 'Abalessa',
      titleAr: 'أباليسة',
      lat: 22.873,
      lng: 4.847,
    ),
    NeighborhoodPick(
      titleEn: 'In Ghar',
      titleAr: 'إين غار',
      lat: 27.108,
      lng: 1.808,
    ),
    NeighborhoodPick(
      titleEn: 'In Salah',
      titleAr: 'إين صالح',
      lat: 27.197,
      lng: 2.483,
    ),
    NeighborhoodPick(
      titleEn: 'Tazrouk',
      titleAr: 'تازروك',
      lat: 23.424,
      lng: 5.675,
    ),
    NeighborhoodPick(
      titleEn: 'Idles',
      titleAr: 'إدلس',
      lat: 23.817,
      lng: 5.917,
    ),
    NeighborhoodPick(
      titleEn: 'In Amenas',
      titleAr: 'إين أمenas',
      lat: 28.042,
      lng: 9.553,
      supported: false,
    ),
  ];

  static List<NeighborhoodPick> matching(String query, {String? languageCode}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((e) {
          if (e.titleEn.toLowerCase().contains(q)) return true;
          if (e.titleAr.contains(query.trim())) return true;
          if (languageCode == 'ar' && e.titleAr.contains(query.trim())) {
            return true;
          }
          return false;
        })
        .toList(growable: false);
  }

  /// First supported pick (default map center).
  static NeighborhoodPick get defaultSupported =>
      all.firstWhere((e) => e.supported, orElse: () => all.first);
}

/// Great-circle distance in km.
double neighborhoodDistanceKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  double toRad(double deg) => deg * math.pi / 180;
  final dLat = toRad(lat2 - lat1);
  final dLon = toRad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRad(lat1)) *
          math.cos(toRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

/// True if coordinates are within [maxKm] of any [supported] neighborhood center.
bool coordinatesInSupportedServiceArea(
  double lat,
  double lng, {
  double maxKm = 8,
}) {
  for (final n in NeighborhoodPick.all) {
    if (!n.supported) continue;
    if (neighborhoodDistanceKm(lat, lng, n.lat, n.lng) <= maxKm) {
      return true;
    }
  }
  return false;
}

/// Snaps GPS to the nearest supported neighborhood label (for UX when address is coarse).
NeighborhoodPick? nearestSupportedNeighborhood(double lat, double lng) {
  NeighborhoodPick? best;
  var bestD = double.infinity;
  for (final n in NeighborhoodPick.all) {
    if (!n.supported) continue;
    final d = neighborhoodDistanceKm(lat, lng, n.lat, n.lng);
    if (d < bestD) {
      bestD = d;
      best = n;
    }
  }
  return best;
}
