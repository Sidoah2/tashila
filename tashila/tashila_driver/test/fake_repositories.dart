import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tashila_driver/core/models/models.dart';
import 'package:tashila_driver/core/services/api_client.dart';
import 'package:tashila_driver/core/services/repositories.dart';

/// Succeeds availability PUT/location calls so bootstrap can finish online in tests.
class StubApiClient extends ApiClient {
  StubApiClient();

  @override
  Future<Response<T>> put<T>(String path, {dynamic data}) async {
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: <String, dynamic>{} as T,
    );
  }
}

class FakeProfileRepository implements ProfileRepository {
  const FakeProfileRepository();

  @override
  Future<DriverProfile> saveProfile(DriverProfile profile) async => profile;

  @override
  Future<DriverDocument> uploadDocument(
    DocumentType type, {
    required String filePath,
    String? fileName,
  }) async =>
      DriverDocument(type: type, fileName: fileName, localFilePath: filePath);

  @override
  Future<Map<String, dynamic>?> fetchMe() async => null;

  @override
  Future<Map<String, dynamic>?> fetchDocuments() async => null;

  @override
  Future<Map<String, dynamic>?> fetchApprovalStatus() async => null;
}

class FakeEarningsRepository implements EarningsRepository {
  const FakeEarningsRepository();

  @override
  EarningsSummary buildSummary(List<TripRecord> trips) {
    return const EarningsSummary(
      todayTotal: 0,
      weekTotal: 0,
      todayTrips: 0,
      weekTrips: 0,
    );
  }

  @override
  Future<DriverPlatformEarnings?> fetchPlatformEarnings() async => null;
}

class FakeTripRepository implements TripRepository {
  const FakeTripRepository();

  static const _request = TripRequest(
    id: 'REQ-101',
    clientName: 'Sara',
    pickup: 'Market Street',
    dropOff: 'North District',
    fare: 42,
    distanceKm: 4.8,
    estimatedDurationMinutes: 16,
    pickupLatLng: LatLng(9.032, 38.746),
    dropOffLatLng: LatLng(9.045, 38.768),
  );

  @override
  Future<List<TripRequest>> fetchNearbyRequests() async => const [_request];

  @override
  Future<IncomingOffer?> fetchCurrentOffer() async {
    return IncomingOffer(
      request: _request,
      expiresAt: DateTime.now().toUtc().add(const Duration(seconds: 30)),
    );
  }

  @override
  Future<Map<String, dynamic>?> fetchActiveTrip() async => null;

  @override
  Future<String?> acceptTrip(String tripId) async => null;

  @override
  Future<bool> rejectTrip(String tripId) async => true;

  @override
  Future<bool> cancelTrip(String tripId) async => true;

  @override
  Future<bool> updateTripStatus(String tripId, String status) async => true;

  @override
  Future<bool> rateClient(String tripId, int rating, {String? comment}) async =>
      true;

  @override
  Future<List<TripRecord>> fetchTripHistory({int limit = 50}) async {
    return [
      TripRecord(
        id: _request.id,
        clientName: _request.clientName,
        pickup: _request.pickup,
        dropOff: _request.dropOff,
        distanceKm: _request.distanceKm,
        fare: _request.fare,
        estimatedDurationMinutes: _request.estimatedDurationMinutes,
        completedAt: DateTime.now(),
        cashConfirmed: true,
      ),
    ];
  }
}
