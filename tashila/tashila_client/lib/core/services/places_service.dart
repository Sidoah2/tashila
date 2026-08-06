import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_api_headers/google_api_headers.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tashila_client/core/config/map_config.dart';

final placesServiceProvider = Provider<PlacesService>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  // App-restricted API keys require these headers for HTTPS Places REST calls
  // (no browser Referer). See Google Maps Platform security best practices.
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final uri = options.uri;
        if (uri.host == 'maps.googleapis.com' &&
            uri.path.contains('/maps/api/place/')) {
          try {
            final headers = await GoogleApiHeaders().getHeaders();
            if (headers.isNotEmpty) {
              options.headers.addAll(headers);
            }
          } catch (_) {}
        }
        handler.next(options);
      },
    ),
  );
  return PlacesService(dio);
});

class PlacePrediction {
  const PlacePrediction({
    required this.description,
    required this.placeId,
  });

  final String description;
  final String placeId;
}

class PlaceDetailsResult {
  const PlaceDetailsResult({
    required this.formattedAddress,
    required this.lat,
    required this.lng,
  });

  final String formattedAddress;
  final double lat;
  final double lng;
}

class PlacesService {
  PlacesService(this._dio);

  final Dio _dio;

  static const _autocompleteUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const _detailsUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';

  Future<List<PlacePrediction>> autocomplete({
    required String input,
    required String language,
    double? biasLat,
    double? biasLng,
    int radiusMeters = 50000,
  }) async {
    if (!MapConfig.canRenderGoogleMap) return [];
    final trimmed = input.trim();
    if (trimmed.isEmpty) return [];

    final query = <String, dynamic>{
      'input': trimmed,
      'key': MapConfig.mapApiKey,
      'language': language,
      // Limits predictions to Algeria; remove if you need cross-border search.
      'components': 'country:dz',
    };
    if (biasLat != null && biasLng != null) {
      query['location'] = '$biasLat,$biasLng';
      query['radius'] = radiusMeters;
    }

    final response = await _dio.get<Map<String, dynamic>>(_autocompleteUrl, queryParameters: query);
    final data = response.data;
    if (data == null) return [];
    final status = data['status'] as String?;
    final googleErr = data['error_message'] as String?;
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      throw PlacesException(status ?? 'UNKNOWN', googleErr);
    }
    final list = data['predictions'] as List<dynamic>? ?? [];
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return PlacePrediction(
        description: m['description'] as String? ?? '',
        placeId: m['place_id'] as String? ?? '',
      );
    }).where((p) => p.placeId.isNotEmpty).toList();
  }

  Future<PlaceDetailsResult?> placeDetails({
    required String placeId,
    required String language,
  }) async {
    if (!MapConfig.canRenderGoogleMap) return null;

    final response = await _dio.get<Map<String, dynamic>>(
      _detailsUrl,
      queryParameters: {
        'place_id': placeId,
        'key': MapConfig.mapApiKey,
        'language': language,
        'fields': 'formatted_address,geometry/location',
      },
    );
    final data = response.data;
    if (data == null) {
      throw PlacesException('NO_BODY', null);
    }
    final status = data['status'] as String?;
    final googleErr = data['error_message'] as String?;
    if (status != 'OK') {
      throw PlacesException(status ?? 'UNKNOWN', googleErr);
    }
    final result = data['result'] as Map<String, dynamic>?;
    if (result == null) return null;
    final geometry = result['geometry'] as Map<String, dynamic>?;
    final loc = geometry?['location'] as Map<String, dynamic>?;
    if (loc == null) return null;
    final lat = (loc['lat'] as num?)?.toDouble();
    final lng = (loc['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return PlaceDetailsResult(
      formattedAddress: result['formatted_address'] as String? ?? '',
      lat: lat,
      lng: lng,
    );
  }

  Future<String?> reverseGeocode({
    required double lat,
    required double lng,
    required String language,
  }) async {
    if (!MapConfig.canRenderGoogleMap) return null;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'latlng': '$lat,$lng',
          'key': MapConfig.mapApiKey,
          'language': language,
        },
      );
      final data = response.data;
      if (data == null || data['status'] != 'OK') return null;
      final results = data['results'] as List<dynamic>?;
      if (results != null && results.isNotEmpty) {
        final first = results.first as Map<String, dynamic>;
        return first['formatted_address'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<List<LatLng>> fetchDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    if (!MapConfig.canRenderGoogleMap) return [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: {
          'origin': '$originLat,$originLng',
          'destination': '$destLat,$destLng',
          'key': MapConfig.mapApiKey,
        },
      );
      final data = response.data;
      if (data == null || data['status'] != 'OK') return [];
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return [];
      final firstRoute = routes.first as Map<String, dynamic>;
      final overviewPolyline = firstRoute['overview_polyline'] as Map<String, dynamic>?;
      final pointsStr = overviewPolyline?['points'] as String?;
      if (pointsStr == null || pointsStr.isEmpty) return [];
      return decodePolyline(pointsStr);
    } catch (_) {
      return [];
    }
  }
}

List<LatLng> decodePolyline(String encoded) {
  List<LatLng> points = [];
  int index = 0, len = encoded.length;
  int lat = 0, lng = 0;

  while (index < len) {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    points.add(LatLng(lat / 1E5, lng / 1E5));
  }
  return points;
}

class PlacesException implements Exception {
  PlacesException(this.status, [this.googleErrorMessage]);

  /// Google `status` string, e.g. REQUEST_DENIED, OVER_QUERY_LIMIT.
  final String status;

  /// Raw `error_message` from the API response when present.
  final String? googleErrorMessage;

  @override
  String toString() =>
      'PlacesException($status${googleErrorMessage != null ? ': $googleErrorMessage' : ''})';
}
