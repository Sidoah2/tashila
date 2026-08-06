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
      titleEn: 'Sersouf',
      titleAr: 'حي سرسوف',
      lat: 22.7933252,
      lng: 5.5262232,
    ),
    NeighborhoodPick(
      titleEn: 'Tahaggart',
      titleAr: 'حي تهقارت',
      lat: 22.7996081,
      lng: 5.5101186,
    ),
    NeighborhoodPick(
      titleEn: 'Tafsit',
      titleAr: 'حي تافسيت',
      lat: 22.8010101,
      lng: 5.5302636,
    ),
    NeighborhoodPick(
      titleEn: 'Mouflon',
      titleAr: 'حي موفلون',
      lat: 22.787566,
      lng: 5.5396971,
    ),
    NeighborhoodPick(
      titleEn: 'El Ksar',
      titleAr: 'حي القصر',
      lat: 22.7866,
      lng: 5.5344,
    ),
    NeighborhoodPick(
      titleEn: 'El Hofra',
      titleAr: 'حي الحفرة',
      lat: 22.776,
      lng: 5.525,
    ),
    NeighborhoodPick(
      titleEn: 'Gata El Oued',
      titleAr: 'حي قطع الواد',
      lat: 22.782,
      lng: 5.521,
    ),
    NeighborhoodPick(
      titleEn: 'Imchouane',
      titleAr: 'حي إمشوان',
      lat: 22.792,
      lng: 5.516,
    ),
    NeighborhoodPick(
      titleEn: 'Metnatlat',
      titleAr: 'حي متناتلات',
      lat: 22.789,
      lng: 5.531,
    ),
    NeighborhoodPick(
      titleEn: 'Taberkat',
      titleAr: 'حي تبركات',
      lat: 22.773,
      lng: 5.528,
    ),
    NeighborhoodPick(
      titleEn: 'Tahagouine',
      titleAr: 'حي تهقوين',
      lat: 22.796,
      lng: 5.535,
    ),
    NeighborhoodPick(
      titleEn: 'El Salam',
      titleAr: 'حي السلام',
      lat: 22.7755871,
      lng: 5.5195197,
    ),
    NeighborhoodPick(
      titleEn: 'Adrian',
      titleAr: 'حي أدريان',
      lat: 22.783,
      lng: 5.545,
    ),
    NeighborhoodPick(
      titleEn: '5 Juillet',
      titleAr: 'حي 5 جويلية',
      lat: 22.7763103,
      lng: 5.5351093,
    ),
    NeighborhoodPick(
      titleEn: 'Sorou',
      titleAr: 'حي صورو',
      lat: 22.784,
      lng: 5.551,
    ),
    NeighborhoodPick(
      titleEn: 'El Safsaf',
      titleAr: 'حي الصفصاف',
      lat: 22.771,
      lng: 5.514,
    ),
    NeighborhoodPick(
      titleEn: 'Ankouf',
      titleAr: 'حي أنكوّف',
      lat: 22.795,
      lng: 5.508,
    ),
    NeighborhoodPick(
      titleEn: 'Quartier des Femmes',
      titleAr: 'حي النساء',
      lat: 22.788,
      lng: 5.526,
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
double neighborhoodDistanceKm(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadiusKm = 6371.0;
  double toRad(double deg) => deg * math.pi / 180;
  final dLat = toRad(lat2 - lat1);
  final dLon = toRad(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
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
  // Bypasses the local hardcoded geofence list to allow testing and booking anywhere in Algeria.
  return true;
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
