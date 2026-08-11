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
      titleEn: 'Sersouf El Houanit',
      titleAr: 'حي سرسوف الحوانيت',
      lat: 22.7960625,
      lng: 5.5274375,
    ),
    NeighborhoodPick(
      titleEn: 'Bab El Zouar',
      titleAr: 'حي باب الزوار',
      lat: 22.7974375,
      lng: 5.5093125,
    ),
    NeighborhoodPick(
      titleEn: 'El Choumou',
      titleAr: 'حي الشموع',
      lat: 22.8088125,
      lng: 5.5170625,
    ),
    NeighborhoodPick(
      titleEn: 'El Wiam',
      titleAr: 'حي الوئام',
      lat: 22.7984375,
      lng: 5.5203125,
    ),
    NeighborhoodPick(
      titleEn: 'Tahaggart East',
      titleAr: 'حي تهقارت الشرقية',
      lat: 22.7936875,
      lng: 5.5084375,
    ),
    NeighborhoodPick(
      titleEn: 'Tahaggart West',
      titleAr: 'حي تهقارت الغربية',
      lat: 22.7924375,
      lng: 5.5071875,
    ),
    NeighborhoodPick(
      titleEn: 'El Safsaf',
      titleAr: 'حي الصفصاف',
      lat: 22.7856875,
      lng: 5.5185625,
    ),
    NeighborhoodPick(
      titleEn: 'Tafsit',
      titleAr: 'حي تافسيت',
      lat: 22.8053125,
      lng: 5.5348125,
    ),
    NeighborhoodPick(
      titleEn: 'El Jazeera',
      titleAr: 'حي الجزيرة',
      lat: 22.7694375,
      lng: 5.5468125,
    ),
    NeighborhoodPick(
      titleEn: 'Mouflon',
      titleAr: 'حي موفلون',
      lat: 22.7850625,
      lng: 5.5355625,
    ),
    NeighborhoodPick(
      titleEn: 'El Ksar',
      titleAr: 'حي القصر',
      lat: 22.7880625,
      lng: 5.5291875,
    ),
    NeighborhoodPick(
      titleEn: 'Gata El Oued',
      titleAr: 'حي قطع الواد',
      lat: 22.7851875,
      lng: 5.5094375,
    ),
    NeighborhoodPick(
      titleEn: 'Imchouane',
      titleAr: 'حي إمشوان',
      lat: 22.7774375,
      lng: 5.5328125,
    ),
    NeighborhoodPick(
      titleEn: 'Sersouf Metnatlat',
      titleAr: 'حي سرسوف  متناتلات',
      lat: 22.8143125,
      lng: 5.5236875,
    ),
    NeighborhoodPick(
      titleEn: 'Taberkat',
      titleAr: 'حي تبركات',
      lat: 22.8033125,
      lng: 5.5590625,
    ),
    NeighborhoodPick(
      titleEn: 'Tahagouine',
      titleAr: 'حي تهقوين',
      lat: 22.7779375,
      lng: 5.5080625,
    ),
    NeighborhoodPick(
      titleEn: 'El Salam',
      titleAr: 'حي السلام',
      lat: 22.7713125,
      lng: 5.5169375,
    ),
    NeighborhoodPick(
      titleEn: 'Adrian',
      titleAr: 'حي أدريان',
      lat: 22.7845625,
      lng: 5.5644375,
    ),
    NeighborhoodPick(
      titleEn: 'Ain Gazzam Station',
      titleAr: 'محطة عين قزام',
      lat: 22.7681875,
      lng: 5.5273125,
    ),
    NeighborhoodPick(
      titleEn: '5 Juillet',
      titleAr: 'حي 5 جويلية',
      lat: 22.7726875,
      lng: 5.5388125,
    ),
    NeighborhoodPick(
      titleEn: 'Sorou Kahwa',
      titleAr: 'حي صورو القهوة',
      lat: 22.7921875,
      lng: 5.5461875,
    ),
    NeighborhoodPick(
      titleEn: 'Sorou Maalemin',
      titleAr: 'حي صورو المعلمين',
      lat: 22.7843125,
      lng: 5.5489375,
    ),
    NeighborhoodPick(
      titleEn: 'Sorou Masjid',
      titleAr: 'حي صورو الجامع',
      lat: 22.7890625,
      lng: 5.5424375,
    ),
    NeighborhoodPick(
      titleEn: 'Ankouf',
      titleAr: 'حي أنكوّف',
      lat: 22.7766875,
      lng: 5.5473125,
    ),
    NeighborhoodPick(
      titleEn: 'Quartier des Femmes',
      titleAr: 'حي النساء',
      lat: 22.7753125,
      lng: 5.5525625,
    ),
    NeighborhoodPick(
      titleEn: 'Passenger Station',
      titleAr: 'محطة نقل المسافرين',
      lat: 22.8184375,
      lng: 5.4894375,
    ),
    NeighborhoodPick(
      titleEn: 'Razan Mall',
      titleAr: 'المركز التجاري رزان',
      lat: 22.8369375,
      lng: 5.4464375,
    ),
    NeighborhoodPick(
      titleEn: 'Tamanrasset Airport',
      titleAr: 'مطار تمنراست أقنار',
      lat: 22.8158125,
      lng: 5.4488125,
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
  double? centerLat,
  double? centerLng,
  double? radiusKm,
}) {
  if (centerLat == null || centerLng == null || radiusKm == null) {
    // Falls back to Tamanrasset center and 200 km radius as default
    final dist = neighborhoodDistanceKm(lat, lng, 22.765900134406188, 5.538099427546386);
    return dist <= 200.0;
  }
  final dist = neighborhoodDistanceKm(lat, lng, centerLat, centerLng);
  return dist <= radiusKm;
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
