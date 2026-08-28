import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../config/map_config.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/http_services.dart';
import '../services/repositories.dart';
import '../services/driver_socket_service.dart';
import '../router/app_router.dart';

const kSession = 'driver_session';
const kPhone = 'driver_phone';
const kSeenOnboarding = 'driver_seen_onboarding';
const kProfile = 'driver_profile';
const kProfileSetupComplete = 'driver_profile_setup_complete';
const kAvailability = 'driver_availability';
const kTrips = 'driver_trip_history';

String formatRatingComment(
  String comment,
  List<String> goodTraits,
  List<String> badTraits,
) {
  final parts = <String>[];
  final trimmed = comment.trim();
  if (trimmed.isNotEmpty) parts.add(trimmed);
  if (goodTraits.isNotEmpty) {
    parts.add('${goodTraits.join(', ')} (+)');
  }
  if (badTraits.isNotEmpty) {
    parts.add('${badTraits.join(', ')} (-)');
  }
  return parts.join('\n');
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => HttpAuthRepository(ref.read(apiClientProvider)),
);
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => HttpProfileRepository(ref.read(apiClientProvider)),
);
final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => HttpTripRepository(ref.read(apiClientProvider)),
);
final earningsRepositoryProvider = Provider<EarningsRepository>(
  (ref) => TripHistoryEarningsRepository(ref.read(apiClientProvider)),
);

final driverAppStateProvider =
    NotifierProvider<DriverAppNotifier, DriverAppState>(DriverAppNotifier.new);

class DriverAppState {
  const DriverAppState({
    this.bootstrapped = false,
    this.adminCreated = true,
    this.isAuthenticated = false,
    this.seenOnboarding = false,
    this.profileSetupComplete = false,
    this.phone = '',
    this.profile,
    this.availability = AvailabilityStatus.offline,
    this.incomingOffers = const [],
    this.offerCountdownTick = 0,
    this.currentRequest,
    this.polylinePoints = const [],
    this.tripStatus = TripStatus.idle,
    this.tripHistory = const [],
    this.platformEarnings,
    this.tripStartedAt,
    this.driverLocation,
    this.error,
    this.infoMessage,
    this.isBusy = false,
  });

  final bool bootstrapped;
  final bool adminCreated;
  final bool isAuthenticated;
  final bool seenOnboarding;
  final bool profileSetupComplete;
  final String phone;
  final DriverProfile? profile;
  final AvailabilityStatus availability;
  final List<IncomingOffer> incomingOffers;
  final int offerCountdownTick;

  /// Soonest-expiring offer (exclusive dispatch usually sends one).
  IncomingOffer? get activeOffer {
    if (incomingOffers.isEmpty) return null;
    return incomingOffers.reduce(
      (a, b) => a.expiresAt.isBefore(b.expiresAt) ? a : b,
    );
  }

  final TripRequest? currentRequest;
  final List<LatLng> polylinePoints;
  final TripStatus tripStatus;
  final List<TripRecord> tripHistory;
  final DriverPlatformEarnings? platformEarnings;
  final DateTime? tripStartedAt;
  final LatLng? driverLocation;
  final String? error;
  final String? infoMessage;
  final bool isBusy;

  bool get needsProfileSetup => !(profile?.isReadyForDashboard ?? false);

  bool get hasActiveTrip =>
      currentRequest != null && tripStatus != TripStatus.idle;

  String get startRoute {
    if (!bootstrapped) return '/splash';
    if (!isAuthenticated) {
      if (!seenOnboarding) return '/onboarding';
      return '/login';
    }
    if (needsProfileSetup) return '/profile';
    return '/home';
  }

  DriverAppState copyWith({
    bool? bootstrapped,
    bool? adminCreated,
    bool? isAuthenticated,
    bool? seenOnboarding,
    bool? profileSetupComplete,
    String? phone,
    DriverProfile? profile,
    bool clearProfile = false,
    AvailabilityStatus? availability,
    List<IncomingOffer>? incomingOffers,
    bool clearIncomingOffers = false,
    int? offerCountdownTick,
    TripRequest? currentRequest,
    bool clearCurrentRequest = false,
    List<LatLng>? polylinePoints,
    TripStatus? tripStatus,
    List<TripRecord>? tripHistory,
    DriverPlatformEarnings? platformEarnings,
    bool clearPlatformEarnings = false,
    DateTime? tripStartedAt,
    bool clearTripStartedAt = false,
    LatLng? driverLocation,
    String? error,
    bool clearError = false,
    String? infoMessage,
    bool clearInfoMessage = false,
    bool? isBusy,
  }) {
    return DriverAppState(
      bootstrapped: bootstrapped ?? this.bootstrapped,
      adminCreated: adminCreated ?? this.adminCreated,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      seenOnboarding: seenOnboarding ?? this.seenOnboarding,
      profileSetupComplete: profileSetupComplete ?? this.profileSetupComplete,
      phone: phone ?? this.phone,
      profile: clearProfile ? null : (profile ?? this.profile),
      availability: availability ?? this.availability,
      incomingOffers: clearIncomingOffers
          ? const []
          : (incomingOffers ?? this.incomingOffers),
      offerCountdownTick: offerCountdownTick ?? this.offerCountdownTick,
      currentRequest: clearCurrentRequest
          ? null
          : (currentRequest ?? this.currentRequest),
      polylinePoints: clearCurrentRequest
          ? const []
          : (polylinePoints ?? this.polylinePoints),
      tripStatus: tripStatus ?? this.tripStatus,
      tripHistory: tripHistory ?? this.tripHistory,
      platformEarnings: clearPlatformEarnings
          ? null
          : (platformEarnings ?? this.platformEarnings),
      tripStartedAt: clearTripStartedAt
          ? null
          : (tripStartedAt ?? this.tripStartedAt),
      driverLocation: driverLocation ?? this.driverLocation,
      error: clearError ? null : (error ?? this.error),
      infoMessage: clearInfoMessage ? null : (infoMessage ?? this.infoMessage),
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

class DriverAppNotifier extends Notifier<DriverAppState> {
  late final AuthRepository _authRepository;
  late final ProfileRepository _profileRepository;
  late final TripRepository _tripRepository;
  late final EarningsRepository _earningsRepository;
  late final ApiClient _apiClient;
  Timer? _requestPollTimer;
  Timer? _activeTripPollTimer;
  Timer? _offerCountdownTimer;
  Timer? _locationTimer;
  DriverSocketService? _driverSocket;
  final Set<String> _locallyExpiredTripIds = {};
  final StreamController<int> _changeController =
      StreamController<int>.broadcast();

  Stream<int> get stream => _changeController.stream;

  @override
  DriverAppState build() {
    _authRepository = ref.read(authRepositoryProvider);
    _profileRepository = ref.read(profileRepositoryProvider);
    _tripRepository = ref.read(tripRepositoryProvider);
    _earningsRepository = ref.read(earningsRepositoryProvider);
    _apiClient = ref.read(apiClientProvider);
    _apiClient.onUnauthorized = () {
      unawaited(logout());
    };
    _apiClient.onAccountSuspended = () {
      unawaited(handleAccountSuspended());
    };
    ref.onDispose(() {
      _requestPollTimer?.cancel();
      _activeTripPollTimer?.cancel();
      _offerCountdownTimer?.cancel();
      _locationTimer?.cancel();
      _driverSocket?.disconnect();
      _changeController.close();
    });
    _bootstrap();
    return const DriverAppState();
  }

  void _emit() {
    if (!_changeController.isClosed) {
      _changeController.add(DateTime.now().millisecondsSinceEpoch);
    }
  }

  void _setState(DriverAppState next) {
    state = next;
    _emit();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final isAuthenticated = prefs.getBool(kSession) ?? false;
    final seenOnboarding = prefs.getBool(kSeenOnboarding) ?? false;
    final phone = prefs.getString(kPhone) ?? '';
    final rawProfile = prefs.getString(kProfile);
    final profile = rawProfile == null
        ? DriverProfile.empty().copyWith(phone: phone)
        : DriverProfile.fromJson(jsonDecode(rawProfile));
    var profileSetupComplete = prefs.getBool(kProfileSetupComplete);
    if (profileSetupComplete == null && profile.isComplete) {
      profileSetupComplete = true;
      await prefs.setBool(kProfileSetupComplete, true);
    }
    profileSetupComplete ??= false;
    final availabilityName = prefs.getString(kAvailability);
    final availability = availabilityName == null
        ? AvailabilityStatus.offline
        : AvailabilityStatus.values.firstWhere(
            (v) => v.name == availabilityName,
            orElse: () => AvailabilityStatus.offline,
          );

    _setState(
      state.copyWith(
        isAuthenticated: isAuthenticated,
        seenOnboarding: seenOnboarding,
        profileSetupComplete: profileSetupComplete,
        phone: phone,
        profile: profile,
        availability: availability,
        tripHistory: decodeTrips(prefs.getString(kTrips)),
        clearError: true,
      ),
    );

    if (!ref.mounted) return;

    if (isAuthenticated && availability == AvailabilityStatus.online) {
      await _restoreOnlineSession();
    } else if (isAuthenticated) {
      await refreshDriverLocation(sendToServer: false);
      _syncLocationTracking();
    }
    if (!ref.mounted) return;
    if (isAuthenticated) {
      await refreshProfileFromServer();
      if (!ref.mounted) return;
      await _resumeActiveTripIfAny();
      if (!ref.mounted) return;
      await syncTripHistoryFromServer();
      if (!ref.mounted) return;
      await syncPlatformEarningsFromServer();
    }

    _setState(state.copyWith(bootstrapped: true));
  }

  /// Refetch active trip and reconnect socket/poll after app foreground or cold start.
  Future<void> resumeSessionOnForeground() async {
    if (!state.isAuthenticated) return;
    if (state.availability == AvailabilityStatus.online) {
      await _restoreOnlineSession();
    }
    if (!ref.mounted) return;
    await _resumeActiveTripIfAny();
  }

  /// Loads completed trips from the API (replaces local-only mock history).
  Future<void> syncTripHistoryFromServer() async {
    if (!state.isAuthenticated) return;
    try {
      final trips = await _tripRepository.fetchTripHistory();
      await _saveTrips(trips);
      _setState(state.copyWith(tripHistory: trips));
    } catch (_) {}
  }

  Future<void> _resumeActiveTripIfAny() async {
    final trip = await _tripRepository.fetchActiveTrip();
    if (trip == null) {
      _stopActiveTripPolling();
      return;
    }
    await _applyActiveTripFromServer(trip, reconnectSocket: true);
  }

  TripStatus _mapApiStatusToTripStatus(String status) {
    switch (status) {
      case 'completed':
        return TripStatus.awaitingClientRating;
      case 'inProgress':
        return TripStatus.tripInProgress;
      case 'awaitingCash':
        return TripStatus.tripCompletedSummary;
      case 'accepted':
      case 'headingToPickup':
      default:
        return TripStatus.headingToClient;
    }
  }

  TripRequest _tripRequestFromPayload(Map<String, dynamic> trip) {
    final tripId = trip['id'] as String? ?? trip['_id'] as String? ?? '';
    final pickup = trip['pickup'] as Map<String, dynamic>? ?? {};
    final dropoff = trip['dropoff'] as Map<String, dynamic>? ?? {};
    final client = trip['client'] as Map<String, dynamic>? ?? {};
    return TripRequest(
      id: tripId,
      clientName:
          client['name'] as String? ?? trip['clientName'] as String? ?? '',
      clientPhone:
          client['phone'] as String? ?? trip['clientPhone'] as String? ?? '',
      pickup: pickup['address'] as String? ?? '',
      dropOff: dropoff['address'] as String? ?? '',
      fare: ((trip['finalFare'] as num?) ?? (trip['fare'] as num?) ?? 0).toDouble(),
      distanceKm: ((trip['distanceKm'] as num?) ?? 0).toDouble(),
      pickupLatLng: LatLng(
        ((pickup['lat'] as num?) ?? 0).toDouble(),
        ((pickup['lng'] as num?) ?? 0).toDouble(),
      ),
      dropOffLatLng: LatLng(
        ((dropoff['lat'] as num?) ?? 0).toDouble(),
        ((dropoff['lng'] as num?) ?? 0).toDouble(),
      ),
      clientRating:
          ((client['rating'] as num?) ?? (trip['clientRating'] as num?))
              ?.toDouble(),
      clientAvatar:
          client['avatarUrl'] as String? ?? trip['clientAvatar'] as String?,
      startedAt: trip['startedAt'] != null
          ? DateTime.tryParse(trip['startedAt'] as String)
          : null,
      completedAt: trip['completedAt'] != null
          ? DateTime.tryParse(trip['completedAt'] as String)
          : null,
    );
  }

  Future<void> _applyActiveTripFromServer(
    Map<String, dynamic> trip, {
    required bool reconnectSocket,
  }) async {
    final tripId = trip['id'] as String? ?? trip['_id'] as String? ?? '';
    if (tripId.isEmpty) return;

    final status = trip['status'] as String? ?? 'accepted';
    if (status == 'cancelled') {
      _stopActiveTripPolling();
      _setState(
        state.copyWith(
          tripStatus: TripStatus.idle,
          clearCurrentRequest: true,
          clearTripStartedAt: true,
          clearError: true,
        ),
      );
      return;
    }

    final request = _tripRequestFromPayload(trip);
    _setState(
      state.copyWith(
        currentRequest: request,
        tripStatus: _mapApiStatusToTripStatus(status),
        clearIncomingOffers: true,
      ),
    );
    _fetchRouteDirections(request);

    if (reconnectSocket) {
      await _ensureDriverSocket(
        online: state.availability == AvailabilityStatus.online,
      );
      _driverSocket?.joinTrip(tripId);
    }
    _startActiveTripPolling();
  }

  void _startActiveTripPolling() {
    _activeTripPollTimer?.cancel();
    _activeTripPollTimer = Timer.periodic(const Duration(seconds: 3), (
      _,
    ) async {
      if (state.currentRequest == null) {
        _stopActiveTripPolling();
        return;
      }
      final trip = await _tripRepository.fetchActiveTrip();
      if (trip == null) {
        if (state.tripStatus == TripStatus.awaitingClientRating) {
          return;
        }
        _stopActiveTripPolling();
        _setState(
          state.copyWith(
            tripStatus: TripStatus.idle,
            clearCurrentRequest: true,
            clearTripStartedAt: true,
          ),
        );
        return;
      }
      final status = trip['status'] as String? ?? '';
      if (status == 'cancelled') {
        _stopActiveTripPolling();
        _handleTripCancelledByClient({'tripId': state.currentRequest?.id});
        return;
      }
      await _applyActiveTripFromServer(trip, reconnectSocket: false);
    });
  }

  void _stopActiveTripPolling() {
    _activeTripPollTimer?.cancel();
    _activeTripPollTimer = null;
  }

  /// Re-sync online state with the API after app restart/hot restart.
  /// Local prefs may say "online" while the server marked the driver offline
  /// when the previous socket disconnected.
  Future<void> _restoreOnlineSession() async {
    try {
      await _apiClient.put<Map<String, dynamic>>(
        '/drivers/me/availability',
        data: {'availability': 'online'},
      );
    } catch (e) {
      if (!ref.mounted) return;
      _setState(
        state.copyWith(
          error: 'Could not restore online session: ${e.toString()}',
        ),
      );
      return;
    }
    if (!ref.mounted) return;
    await refreshDriverLocation();
    if (!ref.mounted) return;
    await _ensureDriverSocket(online: true);
    if (!ref.mounted) return;
    _syncLocationTracking();
    await refreshNearbyRequests();

    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      if (!isRunning) {
        await service.startService();
      }
    } catch (e) {
      debugPrint('Failed to start background service: $e');
    }
    if (!ref.mounted) return;
    _startRequestPolling();
  }

  void clearError() => _setState(state.copyWith(clearError: true));

  Future<void> updateProfile({
    required String name,
    required String vehicleModel,
    required String vehicleColor,
    required String vehiclePlate,
  }) async {
    _setState(state.copyWith(isBusy: true, clearError: true));
    try {
      final updatedProfile = (state.profile ?? DriverProfile.empty()).copyWith(
        name: name,
        vehicleModel: vehicleModel,
        vehicleColor: vehicleColor,
        vehiclePlate: vehiclePlate,
      );
      try {
        await _profileRepository.saveProfile(updatedProfile);
      } catch (_) {}
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kProfile, jsonEncode(updatedProfile.toJson()));
      _setState(state.copyWith(profile: updatedProfile, isBusy: false));
    } catch (e) {
      _setState(state.copyWith(isBusy: false, error: e.toString()));
      rethrow;
    }
  }

  Future<void> requestOtp(String phone) async {
    _setState(state.copyWith(isBusy: true, clearError: true, phone: phone));
    try {
      await _authRepository.requestOtp(phone);
      _setState(state.copyWith(isBusy: false));
    } catch (e) {
      String errMsg = e.toString();
      if (e is DioException) {
        if (e.response?.statusCode == 429) {
          errMsg = 'otp_rate_limit_err'.tr();
        } else {
          final data = e.response?.data;
          if (data is Map && data['detail'] == 'Account suspended') {
            errMsg = 'account_suspended_err'.tr();
          } else if (data is String && data.contains('Account suspended')) {
            errMsg = 'account_suspended_err'.tr();
          }
        }
      }
      // Store the phone regardless so the OTP screen can show it and resend.
      _setState(state.copyWith(error: errMsg, isBusy: false));
      rethrow;
    }
  }

  Future<bool> verifyOtp(String otp) async {
    _setState(state.copyWith(isBusy: true, clearError: true));
    try {
      final result = await _authRepository.verifyOtp(
        phone: state.phone,
        otp: otp,
      );
      if (!result.success) {
        _setState(state.copyWith(error: 'invalid_otp'.tr(), isBusy: false));
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kSession, true);
      await prefs.setString(kPhone, state.phone);
      await prefs.setBool(kProfileSetupComplete, result.profileComplete);

      await refreshProfileFromServer();

      _setState(
        state.copyWith(
          isAuthenticated: true,
          profileSetupComplete: result.profileComplete,
          isBusy: false,
        ),
      );
      await _resumeActiveTripIfAny();
      await syncTripHistoryFromServer();
      await syncPlatformEarningsFromServer();
      if (state.availability == AvailabilityStatus.online) {
        await _restoreOnlineSession();
      } else {
        await refreshDriverLocation(sendToServer: false);
        _syncLocationTracking();
      }
      return true;
    } catch (e) {
      String errMsg = e.toString();
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['detail'] == 'Account suspended') {
          errMsg = 'account_suspended_err'.tr();
        } else if (data is String && data.contains('Account suspended')) {
          errMsg = 'account_suspended_err'.tr();
        }
      }
      _setState(state.copyWith(error: errMsg, isBusy: false));
      return false;
    }
  }

  Future<bool> verifyFirebaseOtp(String phone, String firebaseIdToken) async {
    _setState(state.copyWith(isBusy: true, clearError: true, phone: phone));
    try {
      final result = await _authRepository.verifyFirebaseOtp(
        phone: phone,
        firebaseIdToken: firebaseIdToken,
      );
      if (!result.success) {
        _setState(state.copyWith(error: 'invalid_otp'.tr(), isBusy: false));
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kSession, true);
      await prefs.setString(kPhone, phone);
      await prefs.setBool(kProfileSetupComplete, result.profileComplete);

      await refreshProfileFromServer();

      _setState(
        state.copyWith(
          isAuthenticated: true,
          profileSetupComplete: result.profileComplete,
          isBusy: false,
        ),
      );
      await _resumeActiveTripIfAny();
      await syncTripHistoryFromServer();
      await syncPlatformEarningsFromServer();
      if (state.availability == AvailabilityStatus.online) {
        await _restoreOnlineSession();
      } else {
        await refreshDriverLocation(sendToServer: false);
        _syncLocationTracking();
      }
      return true;
    } catch (e) {
      _setState(state.copyWith(error: e.toString(), isBusy: false));
      return false;
    }
  }

  Future<void> logout() async {
    _requestPollTimer?.cancel();
    _offerCountdownTimer?.cancel();
    _locationTimer?.cancel();
    await _driverSocket?.disconnect();
    _locallyExpiredTripIds.clear();

    try {
      FlutterBackgroundService().invoke('stopService');
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setBool(kSeenOnboarding, true);
    await ref.read(apiClientProvider).clearTokens();
    _setState(
      const DriverAppState(
        bootstrapped: true,
        isAuthenticated: false,
        seenOnboarding: true,
        profile: null,
      ),
    );
  }

  Future<void> handleAccountSuspended() async {
    await logout();
    final ctx = rootNavigatorKey.currentContext;
    if (ctx != null) {
      final locale = Localizations.localeOf(ctx);
      final isAr = locale.languageCode == 'ar';
      final isFr = locale.languageCode == 'fr';

      final title = isAr ? 'الحساب موقوف' : (isFr ? 'Compte Suspendu' : 'Account Suspended');
      final message = isAr
          ? 'تم إيقاف حسابك من قبل المسؤول. يرجى الاتصال بالدعم الفني.'
          : (isFr
              ? 'Votre compte a été suspendu par l\'administrateur. Veuillez contacter le support client.'
              : 'Your account has been suspended by the administrator. Please contact customer support.');

      showDialog<void>(
        context: ctx,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void clearInfoMessage() {
    _setState(state.copyWith(clearInfoMessage: true));
  }

  /// Clears local driver data and signs out, but keeps marketing onboarding seen
  /// (same idea as the client app delete-account flow).
  Future<void> deleteAccount() async {
    _requestPollTimer?.cancel();
    _offerCountdownTimer?.cancel();
    _locationTimer?.cancel();
    try {
      await _apiClient.delete('/drivers/me');
    } catch (_) {}
    await _driverSocket?.disconnect();

    try {
      FlutterBackgroundService().invoke('stopService');
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(kSeenOnboarding) ?? false;
    await prefs.clear();
    await ref.read(apiClientProvider).clearTokens();
    if (seen) {
      await prefs.setBool(kSeenOnboarding, true);
    }
    _setState(
      DriverAppState(bootstrapped: true, seenOnboarding: seen, profile: null),
    );
  }

  Future<void> setSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kSeenOnboarding, true);
    _setState(state.copyWith(seenOnboarding: true));
  }

  /// Loads platform earnings from `GET /drivers/me/earnings`.
  Future<void> syncPlatformEarningsFromServer() async {
    if (!state.isAuthenticated) return;
    try {
      final earnings = await _earningsRepository.fetchPlatformEarnings();
      if (earnings == null) return;
      _setState(state.copyWith(platformEarnings: earnings));
    } catch (_) {}
  }

  Future<void> saveProfile({
    required String name,
    required String phone,
    String? email,
    String? truckType,
    String? vehiclePlate,
    String? vehicleColor,
    String? vehicleModel,
  }) async {
    _setState(state.copyWith(isBusy: true, clearError: true));
    final current = state.profile ?? DriverProfile.empty();
    final nextTruck = truckType?.trim();
    final truckChanged =
        nextTruck != null &&
        nextTruck.isNotEmpty &&
        nextTruck != current.truckType.trim();
    final merged = truckChanged
        ? current.copyWith(
            name: name,
            phone: phone,
            email: email ?? current.email,
            truckType: nextTruck,
            vehiclePlate: vehiclePlate ?? current.vehiclePlate,
            vehicleColor: vehicleColor ?? current.vehicleColor,
            vehicleModel: vehicleModel ?? current.vehicleModel,
            documentsApproved: false,
          )
        : current.copyWith(
            name: name,
            phone: phone,
            email: email ?? current.email,
            truckType: nextTruck,
            vehiclePlate: vehiclePlate ?? current.vehiclePlate,
            vehicleColor: vehicleColor ?? current.vehicleColor,
            vehicleModel: vehicleModel ?? current.vehicleModel,
          );
    final profile = await _profileRepository.saveProfile(merged);
    final pendingApproval = profile.isComplete && !profile.documentsApproved;
    final saved = pendingApproval
        ? profile.copyWith(documentsApproved: false)
        : profile;
    await _saveProfile(saved);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kProfileSetupComplete, saved.isComplete);
    _setState(
      state.copyWith(
        profile: saved,
        profileSetupComplete: saved.isComplete,
        isBusy: false,
      ),
    );
  }

  Future<void> uploadDocument(
    DocumentType type, {
    String? fileName,
    String? filePath,
  }) async {
    if (filePath == null || filePath.isEmpty) return;
    _setState(state.copyWith(isBusy: true, clearError: true));
    try {
      final uploaded = await _profileRepository.uploadDocument(
        type,
        filePath: filePath,
        fileName: fileName,
      );
      final profile = state.profile ?? DriverProfile.empty();
      final docs = profile.documents
          .map((d) => d.type == type ? uploaded : d)
          .toList(growable: false);
      final updated = profile.copyWith(
        documents: docs,
        documentsApproved: false,
      );

      await _saveProfile(updated);
      _setState(state.copyWith(profile: updated, isBusy: false));
    } catch (_) {
      _setState(
        state.copyWith(
          isBusy: false,
          error: 'Document upload failed. Please try again.',
        ),
      );
    }
  }

  Future<void> syncApprovalFromServer() async {
    final status = await _profileRepository.fetchApprovalStatus();
    if (status == null) return;
    final approval = status['approvalStatus'] as String? ?? 'pending';
    final rejectionReason = status['rejectionReason'] as String?;
    final approved = approval == 'approved';
    final profile = state.profile;
    if (profile == null) return;
    final updated = profile.copyWith(
      documentsApproved: approved,
      approvalStatus: approval,
      rejectionReason: rejectionReason,
    );
    await _saveProfile(updated);
    _setState(state.copyWith(profile: updated));
  }

  Future<void> refreshProfileFromServer() async {
    final me = await _profileRepository.fetchMe();
    if (me == null) return;
    final docsPayload = await _profileRepository.fetchDocuments();
    final profile = state.profile ?? DriverProfile.empty();
    final profileComplete = me['profileComplete'] as bool? ?? false;
    final rawApproval = me['approvalStatus'] as String? ?? 'pending';
    final rejectionReason = me['rejectionReason'] as String?;
    final updated = profile.copyWith(
      name: me['name'] as String? ?? profile.name,
      phone: me['phone'] as String? ?? profile.phone,
      truckType: migrateTruckType(
        me['truckType'] as String? ?? profile.truckType,
      ),
      documentsApproved: rawApproval == 'approved',
      approvalStatus: rawApproval,
      rejectionReason: rejectionReason,
      avatarUrl: me['avatarUrl'] as String? ?? profile.avatarUrl,
      vehiclePlate: me['vehiclePlate'] as String? ?? profile.vehiclePlate,
      vehicleColor: me['vehicleColor'] as String? ?? profile.vehicleColor,
      vehicleModel: me['vehicleModel'] as String? ?? profile.vehicleModel,
      documents: mergeServerDocuments(
        profile.documents,
        docsPayload?['documents'] as Map<String, dynamic>?,
      ),
    );
    await _saveProfile(updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kProfileSetupComplete, profileComplete);
    _setState(
      state.copyWith(profile: updated, profileSetupComplete: profileComplete),
    );
  }

  Future<void> setProfilePhotoPath(String? localPath) async {
    debugPrint('[AVATAR] setProfilePhotoPath called — localPath=$localPath');
    final current = state.profile ?? DriverProfile.empty();
    debugPrint(
      '[AVATAR] current.profilePhotoPath=${current.profilePhotoPath}  avatarUrl=${current.avatarUrl}',
    );
    debugPrint('[AVATAR] isReadyForDashboard=${current.isReadyForDashboard}');
    _setState(state.copyWith(isBusy: true, clearError: true));

    // Try to upload to the backend. Do NOT call saveProfile() which hits
    // the profile-setup endpoint (wrong endpoint for avatar-only changes).
    String? avatarUrl;
    bool uploadFailed = false;
    if (localPath != null && localPath.isNotEmpty) {
      final httpRepo = _profileRepository;
      debugPrint(
        '[AVATAR] _profileRepository runtimeType=${httpRepo.runtimeType}',
      );
      if (httpRepo is HttpProfileRepository) {
        debugPrint(
          '[AVATAR] Starting uploadAvatar to PUT /drivers/me/avatar ...',
        );
        try {
          avatarUrl = await httpRepo.uploadAvatar(localPath);
          debugPrint(
            '[AVATAR] uploadAvatar SUCCESS — returned avatarUrl=$avatarUrl',
          );
        } catch (e, st) {
          debugPrint('[AVATAR] uploadAvatar FAILED — error: $e');
          debugPrint('[AVATAR] stack: $st');
          uploadFailed = true;
        }
      } else {
        debugPrint(
          '[AVATAR] Repository is NOT HttpProfileRepository — skip backend upload',
        );
      }
    } else {
      debugPrint('[AVATAR] localPath is null/empty — clearing avatar');
    }

    // Always persist the local path so the photo shows in the UI immediately,
    // even if the backend upload failed.
    final updated = current.copyWith(
      profilePhotoPath: localPath,
      clearProfilePhoto: localPath == null,
      // Only update avatarUrl if backend upload succeeded.
      avatarUrl: avatarUrl ?? (localPath == null ? null : current.avatarUrl),
    );
    debugPrint(
      '[AVATAR] updated.profilePhotoPath=${updated.profilePhotoPath}  avatarUrl=${updated.avatarUrl}  uploadFailed=$uploadFailed',
    );
    await _saveProfile(updated);
    debugPrint('[AVATAR] local profile saved');
    _setState(
      state.copyWith(
        profile: updated,
        isBusy: false,
        // Surface a non-blocking error only if upload actually failed.
        error: uploadFailed ? 'error_updating_profile'.tr() : null,
      ),
    );
    debugPrint('[AVATAR] state updated — done');
  }

  Future<void> setAvailability(AvailabilityStatus status) async {
    if (status == AvailabilityStatus.online &&
        !(state.profile?.documentsApproved ?? false)) {
      _setState(state.copyWith(error: 'documents_not_approved_online'.tr()));
      return;
    }
    final apiStatus = status == AvailabilityStatus.online
        ? 'online'
        : 'offline';
    try {
      await _apiClient.put<Map<String, dynamic>>(
        '/drivers/me/availability',
        data: {'availability': apiStatus},
      );
    } catch (e) {
      _setState(state.copyWith(error: e.toString()));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kAvailability, status.name);
    _setState(state.copyWith(availability: status));
    if (status == AvailabilityStatus.online) {
      await refreshDriverLocation();
      await refreshNearbyRequests();
      _startRequestPolling();
      await _ensureDriverSocket(online: true);
      _syncLocationTracking();

      try {
        final service = FlutterBackgroundService();
        final isRunning = await service.isRunning();
        if (!isRunning) {
          await service.startService();
        }
      } catch (e) {
        debugPrint('Failed to start background service: $e');
      }
    } else {
      _requestPollTimer?.cancel();
      _offerCountdownTimer?.cancel();
      await _driverSocket?.disconnect();
      _setState(state.copyWith(clearIncomingOffers: true));
      _syncLocationTracking();

      try {
        FlutterBackgroundService().invoke('stopService');
      } catch (e) {
        debugPrint('Failed to stop background service: $e');
      }
    }
  }

  void _applyIncomingOffer(IncomingOffer offer) {
    if (state.currentRequest != null) return;
    if (_locallyExpiredTripIds.contains(offer.request.id)) return;
    final list = List<IncomingOffer>.from(state.incomingOffers);
    final idx = list.indexWhere((o) => o.request.id == offer.request.id);
    if (idx >= 0 &&
        list[idx].expiresAt == offer.expiresAt &&
        list[idx].offerGeneration == offer.offerGeneration) {
      return;
    }
    if (idx >= 0) {
      list[idx] = offer;
    } else {
      list.add(offer);
      try {
        FlutterRingtonePlayer().play(
          fromAsset: "assets/sounds/notification_sound.mp3",
          looping: false,
          volume: 4.0,
        );
      } catch (e) {
        debugPrint('Failed to play ringtone: $e');
      }
    }
    list.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    _setState(
      state.copyWith(
        incomingOffers: list,
        clearError: true,
        offerCountdownTick: state.offerCountdownTick + 1,
      ),
    );
    _startOfferCountdownTimer();
  }

  void _startOfferCountdownTimer() {
    _offerCountdownTimer?.cancel();
    if (state.incomingOffers.isEmpty) return;
    _offerCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.incomingOffers.isEmpty) {
        _offerCountdownTimer?.cancel();
        return;
      }
      final now = DateTime.now().toUtc();
      final next = state.incomingOffers
          .where((o) => o.expiresAt.isAfter(now))
          .toList(growable: false);
      if (next.length != state.incomingOffers.length) {
        for (final o in state.incomingOffers) {
          if (!o.expiresAt.isAfter(now)) {
            _locallyExpiredTripIds.add(o.request.id);
          }
        }
        _setState(
          state.copyWith(
            incomingOffers: next,
            offerCountdownTick: state.offerCountdownTick + 1,
          ),
        );
        if (next.isEmpty) _offerCountdownTimer?.cancel();
        return;
      }
      _setState(
        state.copyWith(offerCountdownTick: state.offerCountdownTick + 1),
      );
    });
  }

  void _handleTripCancelledByClient(Map<String, dynamic> data) {
    final tripId = data['tripId'] as String?;
    if (tripId == null || tripId.isEmpty) return;

    final isIncomingOffer = state.incomingOffers.any((o) => o.request.id == tripId);
    final isCurrentRequest = state.currentRequest?.id == tripId;

    _clearActiveOffer(tripId: tripId);

    if (isCurrentRequest) {
      _stopActiveTripPolling();
      _setState(
        state.copyWith(
          tripStatus: TripStatus.idle,
          clearCurrentRequest: true,
          clearTripStartedAt: true,
          clearError: true,
          infoMessage: 'trip_cancelled_by_client'.tr(),
        ),
      );
      try {
        FlutterRingtonePlayer().play(
          fromAsset: "assets/sounds/notification_sound.mp3",
          looping: false,
          volume: 4.0,
        );
      } catch (e) {
        debugPrint('Failed to play ringtone: $e');
      }
    } else if (isIncomingOffer) {
      _setState(
        state.copyWith(
          infoMessage: 'trip_cancelled_by_client'.tr(),
        ),
      );
      try {
        FlutterRingtonePlayer().play(
          fromAsset: "assets/sounds/notification_sound.mp3",
          looping: false,
          volume: 4.0,
        );
      } catch (e) {
        debugPrint('Failed to play ringtone: $e');
      }
    }
  }

  void _clearActiveOffer({String? tripId}) {
    if (tripId == null) {
      for (final o in state.incomingOffers) {
        _locallyExpiredTripIds.add(o.request.id);
      }
      _offerCountdownTimer?.cancel();
      _setState(state.copyWith(clearIncomingOffers: true));
      return;
    }
    _locallyExpiredTripIds.add(tripId);
    final next = state.incomingOffers
        .where((o) => o.request.id != tripId)
        .toList(growable: false);
    _setState(state.copyWith(incomingOffers: next));
    if (next.isEmpty) {
      _offerCountdownTimer?.cancel();
    } else {
      _startOfferCountdownTimer();
    }
  }

  String _acceptErrorMessage(String? code) {
    switch (code) {
      case 'OFFER_EXPIRED':
        return 'offer_expired'.tr();
      case 'NOT_YOUR_OFFER':
        return 'offer_not_yours'.tr();
      case 'DRIVER_BUSY':
        return 'offer_driver_busy'.tr();
      case 'TRIP_NOT_AVAILABLE':
        return 'trip_not_available'.tr();
      default:
        return 'Could not accept trip.';
    }
  }

  Future<void> _ensureDriverSocket({required bool online}) async {
    _driverSocket ??= DriverSocketService(_apiClient);
    final connected = await _driverSocket!.connect(
      onTripRequest: (data) {
        final offer = IncomingOffer.fromSocketPayload(data);
        if (offer != null) _applyIncomingOffer(offer);
      },
      onOfferExpired: (data) {
        final tripId = data['tripId'] as String?;
        if (tripId != null && tripId.isNotEmpty) {
          _clearActiveOffer(tripId: tripId);
        } else {
          _clearActiveOffer();
        }
        if (state.availability == AvailabilityStatus.online &&
            state.currentRequest == null) {
          unawaited(refreshNearbyRequests());
        }
      },
      onTripCancelled: (data) => _handleTripCancelledByClient(data),
      onTripError: (data) {
        final code = data['code'] as String?;
        if (code == 'OFFER_EXPIRED' ||
            code == 'NOT_YOUR_OFFER' ||
            code == 'DRIVER_BUSY') {
          _clearActiveOffer();
          _setState(state.copyWith(error: _acceptErrorMessage(code)));
        }
      },
      onReconnect: () {
        if (state.availability == AvailabilityStatus.online &&
            state.currentRequest == null) {
          unawaited(refreshNearbyRequests());
        }
      },
    );
    if (!connected && online) {
      _setState(state.copyWith(error: 'socket_connect_failed'.tr()));
    }
    _driverSocket!.setOnline(online);
  }

  void _syncLocationTracking() {
    _locationTimer?.cancel();
    if (!state.isAuthenticated) return;
    if (state.availability != AvailabilityStatus.online) return;

    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await refreshDriverLocation(sendToServer: true);
      final loc = state.driverLocation;
      if (loc != null) {
        _driverSocket?.sendLocation(lat: loc.latitude, lng: loc.longitude);
      }
    });
  }

  void _startRequestPolling() {
    _requestPollTimer?.cancel();
    _requestPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (state.availability != AvailabilityStatus.online ||
          state.currentRequest != null) {
        return;
      }

      // Check if admin has dispatched/assigned a trip directly to this driver
      try {
        final activeTrip = await _tripRepository.fetchActiveTrip();
        if (activeTrip != null) {
          await _applyActiveTripFromServer(activeTrip, reconnectSocket: true);
          return;
        }
      } catch (_) {}

      if (state.incomingOffers.isNotEmpty) {
        final now = DateTime.now().toUtc();
        final nonExpired = state.incomingOffers
            .where((o) => o.expiresAt.isAfter(now))
            .toList(growable: false);
        if (nonExpired.length != state.incomingOffers.length) {
          _setState(state.copyWith(incomingOffers: nonExpired));
        }
        return;
      }
      final offer = await _tripRepository.fetchCurrentOffer();
      if (offer != null) {
        _applyIncomingOffer(offer);
      }
    });
  }

  Future<void> refreshDriverLocation({bool sendToServer = true}) async {
    try {
      final hasService = await Geolocator.isLocationServiceEnabled();
      if (!hasService) {
        _setState(state.copyWith(error: 'Please enable location services.'));
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setState(state.copyWith(error: 'Location permission is required.'));
        return;
      }

      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _setState(
          state.copyWith(
            driverLocation: LatLng(lastKnown.latitude, lastKnown.longitude),
            clearError: true,
          ),
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final loc = LatLng(position.latitude, position.longitude);
      _setState(state.copyWith(driverLocation: loc, clearError: true));
      if (sendToServer) {
        try {
          await _apiClient.put<Map<String, dynamic>>(
            '/drivers/me/location',
            data: {'lat': loc.latitude, 'lng': loc.longitude},
          );
        } catch (_) {}
      }
    } catch (_) {
      if (state.driverLocation != null) return;
      // Simulator/debug fallback: Bab Ezzouar (supported service area).
      const fallback = LatLng(36.722, 3.182);
      _setState(state.copyWith(driverLocation: fallback));
      if (sendToServer && kDebugMode) {
        try {
          await _apiClient.put<Map<String, dynamic>>(
            '/drivers/me/location',
            data: {'lat': fallback.latitude, 'lng': fallback.longitude},
          );
        } catch (_) {}
      }
    }
  }

  Future<void> refreshNearbyRequests() async {
    if (state.availability == AvailabilityStatus.offline) {
      _setState(state.copyWith(error: 'driver_offline_requests_hint'.tr()));
      return;
    }
    if (state.currentRequest != null) return;
    try {
      final offer = await _tripRepository.fetchCurrentOffer();
      if (offer != null) {
        _applyIncomingOffer(offer);
        return;
      }
      _setState(state.copyWith(clearIncomingOffers: true, clearError: true));
    } catch (e) {
      _setState(state.copyWith(error: e.toString()));
    }
  }

  Future<bool> acceptActiveOffer() async {
    final offer = state.activeOffer;
    if (offer == null) return false;
    return acceptRequest(offer.request);
  }

  Future<bool> acceptRequest(TripRequest request) async {
    if (state.availability != AvailabilityStatus.online) {
      _setState(state.copyWith(error: 'Driver is offline.'));
      return false;
    }
    _setState(state.copyWith(isBusy: true, clearError: true));
    final errorCode = await _tripRepository.acceptTrip(request.id);
    if (errorCode != null) {
      _clearActiveOffer();
      _setState(
        state.copyWith(error: _acceptErrorMessage(errorCode), isBusy: false),
      );
      if (errorCode == 'TRIP_NOT_AVAILABLE') {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null) {
          final locale = Localizations.localeOf(ctx);
          final isAr = locale.languageCode == 'ar';
          final isFr = locale.languageCode == 'fr';
          
          final String title = isAr ? 'عذراً' : (isFr ? 'Désolé' : 'Sorry');
          final String msg = isAr 
              ? 'هذه الرحلة تم قبولها بالفعل من قبل سائق آخر.' 
              : (isFr 
                  ? 'Ce trajet a déjà été pris par un autre chauffeur.' 
                  : 'This trip has already been taken by another driver.');
          
          showDialog<void>(
            context: ctx,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text(title),
              content: Text(msg),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
      return false;
    }
    _clearActiveOffer();
    _driverSocket?.joinTrip(request.id);
    _setState(
      state.copyWith(
        currentRequest: request,
        tripStatus: TripStatus.headingToClient,
        isBusy: false,
        clearError: true,
      ),
    );
    _fetchRouteDirections(request);
    _startActiveTripPolling();
    return true;
  }

  Future<void> rejectActiveOffer() async {
    final offer = state.activeOffer;
    if (offer == null) return;
    await rejectRequest(offer.request);
  }

  Future<void> rejectRequest(TripRequest request) async {
    final ok = await _tripRepository.rejectTrip(request.id);
    if (!ok) {
      _setState(state.copyWith(error: 'Could not reject offer.'));
      return;
    }
    _clearActiveOffer(tripId: request.id);
    _setState(state.copyWith(clearError: true));
  }

  Future<void> confirmArrivedAtClient() async {
    if (state.tripStatus != TripStatus.headingToClient) return;
    final tripId = state.currentRequest?.id;
    if (tripId == null) return;
    _setState(state.copyWith(isBusy: true));
    var ok = await _tripRepository.updateTripStatus(tripId, 'headingToPickup');
    if (ok) {
      ok = await _tripRepository.updateTripStatus(tripId, 'inProgress');
    }
    if (!ok) {
      await _resyncActiveTripFromServer();
      _setState(
        state.copyWith(error: 'Could not update trip status.', isBusy: false),
      );
      return;
    }
    _setState(
      state.copyWith(
        tripStatus: TripStatus.tripInProgress,
        tripStartedAt: DateTime.now(),
        currentRequest: state.currentRequest?.copyWith(
          startedAt: DateTime.now(),
        ),
        isBusy: false,
        clearError: true,
      ),
    );
  }

  Future<void> _resyncActiveTripFromServer() async {
    final trip = await _tripRepository.fetchActiveTrip();
    if (trip == null) {
      _stopActiveTripPolling();
      _setState(
        state.copyWith(
          tripStatus: TripStatus.idle,
          clearCurrentRequest: true,
          clearTripStartedAt: true,
        ),
      );
      return;
    }
    await _applyActiveTripFromServer(trip, reconnectSocket: false);
  }

  Future<void> completeTrip() async {
    if (state.tripStatus != TripStatus.tripInProgress) return;
    final tripId = state.currentRequest?.id;
    if (tripId == null) return;
    _setState(state.copyWith(isBusy: true));
    final ok = await _tripRepository.updateTripStatus(tripId, 'awaitingCash');
    if (!ok) {
      _setState(
        state.copyWith(error: 'Could not complete trip.', isBusy: false),
      );
      return;
    }
    _setState(
      state.copyWith(
        tripStatus: TripStatus.tripCompletedSummary,
        currentRequest: state.currentRequest?.copyWith(
          completedAt:
              state.currentRequest?.startedAt?.add(
                DateTime.now().difference(
                  state.tripStartedAt ?? DateTime.now(),
                ),
              ) ??
              DateTime.now(),
        ),
        isBusy: false,
        clearError: true,
      ),
    );
  }

  Future<void> confirmCashReceived() async {
    final request = state.currentRequest;
    if (request == null ||
        state.tripStatus != TripStatus.tripCompletedSummary) {
      return;
    }
    _setState(state.copyWith(isBusy: true));
    final ok = await _tripRepository.updateTripStatus(request.id, 'completed');
    if (!ok) {
      _setState(
        state.copyWith(error: 'Could not confirm payment.', isBusy: false),
      );
      return;
    }

    _driverSocket?.leaveTrip(request.id);
    await syncTripHistoryFromServer();
    await syncPlatformEarningsFromServer();
    _stopActiveTripPolling();
    _setState(
      state.copyWith(
        tripStatus: TripStatus.awaitingClientRating,
        isBusy: false,
      ),
    );
  }

  Future<void> completeClientRatingSession() async {
    if (state.tripStatus != TripStatus.awaitingClientRating) return;

    final tripId = state.currentRequest?.id;
    _stopActiveTripPolling();
    _setState(
      state.copyWith(
        tripStatus: TripStatus.idle,
        clearCurrentRequest: true,
        clearTripStartedAt: true,
        clearError: true,
        incomingOffers: tripId == null
            ? state.incomingOffers
            : state.incomingOffers
                  .where((o) => o.request.id != tripId)
                  .toList(growable: false),
      ),
    );
  }

  Future<bool> submitClientRating({
    required int rating,
    String comment = '',
    List<String> goodTraits = const [],
    List<String> badTraits = const [],
  }) async {
    if (rating < 1) return false;
    if (state.tripStatus != TripStatus.awaitingClientRating) {
      return false;
    }

    final tripId =
        state.currentRequest?.id ??
        (state.tripHistory.isNotEmpty ? state.tripHistory.first.id : null);
    if (tripId == null) return false;

    final fullComment = formatRatingComment(comment, goodTraits, badTraits);
    final ok = await _tripRepository.rateClient(
      tripId,
      rating,
      comment: fullComment.isEmpty ? null : fullComment,
    );
    if (!ok) {
      _setState(state.copyWith(error: 'rating_submit_failed'.tr()));
      return false;
    }

    await syncTripHistoryFromServer();
    await syncPlatformEarningsFromServer();
    return true;
  }

  /// Ends the post-trip client rating flow after the user confirms in the rating sheet.
  Future<bool> submitClientRatingAndFinish({
    required int rating,
    String comment = '',
    List<String> goodTraits = const [],
    List<String> badTraits = const [],
  }) async {
    final ok = await submitClientRating(
      rating: rating,
      comment: comment,
      goodTraits: goodTraits,
      badTraits: badTraits,
    );
    if (!ok) return false;
    await completeClientRatingSession();
    return true;
  }

  Future<void> cancelActiveTrip() async {
    if (state.tripStatus != TripStatus.headingToClient) return;
    final tripId = state.currentRequest?.id;
    if (tripId == null) return;
    _setState(state.copyWith(isBusy: true, clearError: true));
    final ok = await _tripRepository.cancelTrip(tripId);
    if (!ok) {
      _setState(state.copyWith(error: 'Could not cancel trip.', isBusy: false));
      return;
    }
    _driverSocket?.leaveTrip(tripId);
    _stopActiveTripPolling();
    _setState(
      state.copyWith(
        tripStatus: TripStatus.idle,
        clearCurrentRequest: true,
        clearTripStartedAt: true,
        isBusy: false,
        clearError: true,
      ),
    );
  }

  EarningsSummary get earningsSummary =>
      _earningsRepository.buildSummary(state.tripHistory);

  Future<void> _saveProfile(DriverProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kProfile, jsonEncode(profile.toJson()));
  }

  Future<void> _saveTrips(List<TripRecord> trips) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kTrips, encodeTrips(trips));
  }

  Future<void> _fetchRouteDirections(TripRequest request) async {
    final origin = request.pickupLatLng;
    final dest = request.dropOffLatLng;
    try {
      final dio = Dio();
      final response = await dio.get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: {
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${dest.latitude},${dest.longitude}',
          'key': MapConfig.mapApiKey,
        },
      );
      final data = response.data;
      if (data == null || data['status'] != 'OK') return;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return;
      final firstRoute = routes.first as Map<String, dynamic>;
      final overviewPolyline =
          firstRoute['overview_polyline'] as Map<String, dynamic>?;
      final pointsStr = overviewPolyline?['points'] as String?;
      if (pointsStr == null || pointsStr.isEmpty) return;
      final points = _decodePolyline(pointsStr);
      _setState(state.copyWith(polylinePoints: points));
    } catch (_) {}
  }

  List<LatLng> _decodePolyline(String encoded) {
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
}
