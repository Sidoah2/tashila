import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tashila_driver/core/models/models.dart';
import 'package:tashila_driver/core/services/api_client.dart';
import 'package:tashila_driver/core/services/repositories.dart';
import 'package:tashila_driver/core/utils/geo.dart';
import 'package:tashila_driver/core/utils/picked_image_io.dart';

// ignore: unused_element (kept for exhaustive switch if TruckType enum is added later)


class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._client);

  final ApiClient _client;

  @override
  Future<void> requestOtp(String phone) async {
    await _client.post<Map<String, dynamic>>(
      '/auth/otp/send',
      data: {'phone': phone, 'role': 'driver'},
    );
  }

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final res = await _client.post<Map<String, dynamic>>(
        '/auth/otp/verify',
        data: {'phone': phone, 'otp': otp, 'role': 'driver'},
      );
      final data = res.data;
      if (data == null) {
        return const OtpVerifyResult(success: false);
      }
      final accessToken = data['accessToken'] as String?;
      final refreshToken = data['refreshToken'] as String?;
      if (accessToken == null) {
        return const OtpVerifyResult(success: false);
      }
      await _client.saveTokens(accessToken, refreshToken ?? '');
      final user = data['user'] as Map<String, dynamic>?;
      final profileComplete = user?['profileComplete'] as bool? ?? false;
      return OtpVerifyResult(
        success: true,
        profileComplete: profileComplete,
      );
    } catch (_) {
      return const OtpVerifyResult(success: false);
    }
  }
}

class HttpProfileRepository implements ProfileRepository {
  HttpProfileRepository(this._client);

  final ApiClient _client;

  @override
  Future<DriverProfile> saveProfile(DriverProfile profile) async {
    await _client.post<Map<String, dynamic>>(
      '/drivers/me/profile-setup',
      data: {
        'name': profile.name,
        'truckType': profile.truckType.isNotEmpty
            ? profile.truckType
            : kTruckSingleCabin,
        'vehiclePlate': profile.vehiclePlate.trim(),
        'vehicleColor': profile.vehicleColor.trim(),
        'vehicleModel': profile.vehicleModel.trim(),
      },
    );
    return profile;
  }

  String _docTypePath(DocumentType type) {
    switch (type) {
      case DocumentType.drivingLicense:
        return 'drivingLicense';
      case DocumentType.vehicleRegistration:
        return 'vehicleRegistration';
      case DocumentType.vehiclePhoto:
        return 'vehiclePhoto';
    }
  }

  @override
  Future<DriverDocument> uploadDocument(
    DocumentType type, {
    required String filePath,
    String? fileName,
  }) async {
    final bytes = await readUploadBytes(filePath);
    final name = fileName ?? filePath.split('/').last;
    final res = await _client.uploadFile<Map<String, dynamic>>(
      '/drivers/me/documents/${_docTypePath(type)}',
      'file',
      bytes,
      name,
      method: 'POST',
    );
    final url = res.data?['url'] as String?;
    return DriverDocument(
      type: type,
      fileName: name,
      localFilePath: filePath,
      remoteUrl: url,
      status: DocumentUploadStatus.uploaded,
    );
  }

  @override
  Future<Map<String, dynamic>?> fetchMe() async {
    try {
      final res = await _client.get<Map<String, dynamic>>('/drivers/me');
      return res.data;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchDocuments() async {
    try {
      final res = await _client.get<Map<String, dynamic>>('/drivers/me/documents');
      return res.data;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchApprovalStatus() async {
    try {
      final res =
          await _client.get<Map<String, dynamic>>('/drivers/me/approval-status');
      return res.data;
    } catch (_) {
      return null;
    }
  }

  Future<DriverPlatformEarnings?> fetchEarnings() async {
    try {
      final res = await _client.get<Map<String, dynamic>>('/drivers/me/earnings');
      return DriverPlatformEarnings.fromJson(res.data);
    } catch (_) {
      return null;
    }
  }

  Future<String?> uploadAvatar(String filePath) async {
    final bytes = await readUploadBytes(filePath);
    final name = filePath.split('/').last;
    final res = await _client.uploadFile<Map<String, dynamic>>(
      '/drivers/me/avatar',
      'file',
      bytes,
      name,
    );
    return res.data?['avatarUrl'] as String?;
  }
}

TripRequest _tripRequestFromApiMap(Map<String, dynamic> m) {
  final pickup = m['pickup'] as Map<String, dynamic>? ?? {};
  final dropoff = m['dropoff'] as Map<String, dynamic>? ?? {};
  final pickupLat = ((pickup['lat'] as num?) ?? 0).toDouble();
  final pickupLng = ((pickup['lng'] as num?) ?? 0).toDouble();
  final dropoffLat = ((dropoff['lat'] as num?) ?? 0).toDouble();
  final dropoffLng = ((dropoff['lng'] as num?) ?? 0).toDouble();
  final distanceKm = routeDistanceKm(
    pickupLat: pickupLat,
    pickupLng: pickupLng,
    dropoffLat: dropoffLat,
    dropoffLng: dropoffLng,
    apiDistanceKm: (m['distanceKm'] as num?)?.toDouble(),
  );
  final apiMinutes = (m['estimatedDurationMinutes'] as num?)?.toInt() ??
      (m['estimatedMinutes'] as num?)?.toInt();
  final estimatedDurationMinutes = (apiMinutes != null && apiMinutes > 0)
      ? apiMinutes
      : estimateMinutes(distanceKm);
  final expiresAt = IncomingOffer.parseExpiresAt(m['expiresAt'] as String?);
  final client = m['client'] as Map<String, dynamic>? ?? {};
  return TripRequest(
    id: m['id'] as String? ?? m['tripId'] as String? ?? m['_id'] as String? ?? '',
    clientName: m['clientName'] as String? ?? client['name'] as String? ?? '',
    clientPhone:
        m['clientPhone'] as String? ?? client['phone'] as String? ?? '',
    pickup: pickup['address'] as String? ?? '$pickupLat,$pickupLng',
    dropOff: dropoff['address'] as String? ?? '$dropoffLat,$dropoffLng',
    fare: ((m['fare'] as num?) ?? 0).toDouble(),
    distanceKm: distanceKm,
    estimatedDurationMinutes: estimatedDurationMinutes,
    pickupLatLng: LatLng(pickupLat, pickupLng),
    dropOffLatLng: LatLng(dropoffLat, dropoffLng),
    expiresAt: expiresAt,
    truckType: migrateTruckType(m['truckType'] as String?),
  );
}

class HttpTripRepository implements TripRepository {
  HttpTripRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<TripRequest>> fetchNearbyRequests() async {
    try {
      final res = await _client
          .get<List<dynamic>>('/drivers/me/trip-requests');
      final items = res.data ?? [];
      return items
          .map((item) => _tripRequestFromApiMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load trip requests: $e');
    }
  }

  @override
  Future<IncomingOffer?> fetchCurrentOffer() async {
    try {
      final res = await _client.get<Map<String, dynamic>>(
        '/drivers/me/current-offer',
      );
      final offer = res.data?['offer'];
      if (offer == null) return null;
      final m = offer as Map<String, dynamic>;
      final request = _tripRequestFromApiMap(m);
      final expiresAt = request.expiresAt ?? IncomingOffer.parseExpiresAt(null);
      final offeredAtRaw = m['offeredAt'] as String?;
      DateTime offeredAt;
      if (offeredAtRaw != null && offeredAtRaw.isNotEmpty) {
        final parsed = DateTime.tryParse(offeredAtRaw);
        offeredAt = parsed != null
            ? (parsed.isUtc ? parsed : parsed.toUtc())
            : expiresAt.subtract(
                const Duration(seconds: IncomingOffer.defaultTtlSeconds),
              );
      } else {
        offeredAt = expiresAt.subtract(
          const Duration(seconds: IncomingOffer.defaultTtlSeconds),
        );
      }
      return IncomingOffer(
        request: request,
        expiresAt: expiresAt,
        offeredAt: offeredAt,
        offerGeneration: (m['offerGeneration'] as num?)?.toInt(),
        pickupDistanceKm: (m['pickupDistanceKm'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchActiveTrip() async {
    try {
      final res = await _client.get<Map<String, dynamic>>(
        '/drivers/me/active-trip',
      );
      final trip = res.data?['trip'];
      if (trip is Map<String, dynamic>) return trip;
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> acceptTrip(String tripId) async {
    try {
      await _client.post<Map<String, dynamic>>('/trips/$tripId/accept');
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return data['code'] as String? ??
            data['detail'] as String? ??
            'ACCEPT_FAILED';
      }
      return 'ACCEPT_FAILED';
    } catch (_) {
      return 'ACCEPT_FAILED';
    }
  }

  @override
  Future<bool> rejectTrip(String tripId) async {
    try {
      await _client.post<void>('/trips/$tripId/reject');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> cancelTrip(String tripId) async {
    try {
      await _client.post<void>('/trips/$tripId/driver-cancel');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> updateTripStatus(String tripId, String status) async {
    try {
      await _client.put<Map<String, dynamic>>(
        '/trips/$tripId/status',
        data: {'status': status},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> rateClient(String tripId, int rating, {String? comment}) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '/trips/$tripId/rate-client',
        data: {'rating': rating, 'comment': comment},
      );
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<TripRecord>> fetchTripHistory({int limit = 50}) async {
    try {
      final res = await _client.get<Map<String, dynamic>>(
        '/drivers/me/trips',
        queryParameters: {'page': 1, 'limit': limit},
      );
      final items = (res.data?['items'] as List<dynamic>?) ?? [];
      return items
          .map((e) => TripRecord.fromApiTrip(e as Map<String, dynamic>))
          .whereType<TripRecord>()
          .toList();
    } catch (_) {
      return [];
    }
  }
}
