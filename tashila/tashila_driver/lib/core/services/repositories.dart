import '../models/models.dart';
import 'api_client.dart';

class OtpVerifyResult {
  const OtpVerifyResult({required this.success, this.profileComplete = false});

  final bool success;
  final bool profileComplete;
}

abstract class AuthRepository {
  Future<void> requestOtp(String phone);
  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String otp,
  });
}

abstract class ProfileRepository {
  Future<DriverProfile> saveProfile(DriverProfile profile);
  Future<DriverDocument> uploadDocument(
    DocumentType type, {
    required String filePath,
    String? fileName,
  });
  Future<Map<String, dynamic>?> fetchMe();
  Future<Map<String, dynamic>?> fetchDocuments();
  Future<Map<String, dynamic>?> fetchApprovalStatus();
}

abstract class TripRepository {
  Future<List<TripRequest>> fetchNearbyRequests();
  Future<IncomingOffer?> fetchCurrentOffer();
  Future<Map<String, dynamic>?> fetchActiveTrip();
  Future<String?> acceptTrip(String tripId);
  Future<bool> rejectTrip(String tripId);
  Future<bool> cancelTrip(String tripId);
  Future<bool> updateTripStatus(String tripId, String status);
  Future<bool> rateClient(String tripId, int rating, {String? comment});
  Future<List<TripRecord>> fetchTripHistory({int limit = 50});
}

abstract class EarningsRepository {
  EarningsSummary buildSummary(List<TripRecord> trips);
  Future<DriverPlatformEarnings?> fetchPlatformEarnings();
}

class TripHistoryEarningsRepository implements EarningsRepository {
  TripHistoryEarningsRepository(this._client);

  final ApiClient? _client;

  TripHistoryEarningsRepository.local() : _client = null;

  @override
  Future<DriverPlatformEarnings?> fetchPlatformEarnings() async {
    final client = _client;
    if (client == null) return null;
    try {
      final res = await client.get<Map<String, dynamic>>(
        '/drivers/me/earnings',
      );
      return DriverPlatformEarnings.fromJson(res.data);
    } catch (_) {
      return null;
    }
  }

  @override
  EarningsSummary buildSummary(List<TripRecord> trips) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    final todayTrips = trips.where(
      (t) => t.completedAt.isAfter(
        startOfDay.subtract(const Duration(seconds: 1)),
      ),
    );
    final weekTrips = trips.where(
      (t) => t.completedAt.isAfter(
        startOfWeek.subtract(const Duration(seconds: 1)),
      ),
    );

    double sum(Iterable<TripRecord> items) =>
        items.fold(0, (acc, item) => acc + item.fare);

    return EarningsSummary(
      todayTotal: sum(todayTrips),
      weekTotal: sum(weekTrips),
      todayTrips: todayTrips.length,
      weekTrips: weekTrips.length,
    );
  }
}
