import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tashila_client/core/services/api_client.dart';
import 'package:tashila_client/core/services/places_service.dart';
import 'package:tashila_client/core/services/trip_socket_service.dart';

enum TruckType { singleCabine, doubleCabine }

/// Customer-visible trip lifecycle.
enum TripStage {
  idle,
  searchingDriver,
  noDriversFound,
  driverEnRoute,
  tripStarted,
  awaitingPayment,
  arrivedSummary,
}

/// Fallback when distance is unavailable (should match [estimateFareDzd] for a short route).
const double kEstimatedTripPrice = 1000;

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

/// Dynamic fare: base 1000 DZD (first 5 km), +100 DZD/km after 5 km, +20 DZD/min after 60 min, rounded up to 100 DZD.
double estimateFareDzd(double distanceKm, {double tripMinutes = 0}) {
  final raw =
      1000 +
      math.max(0, distanceKm - 5) * 100 +
      math.max(0, tripMinutes - 60) * 20;
  return (raw / 100).ceil() * 100;
}

/// Great-circle distance in kilometers (pickup → drop-off).
double tripRouteDistanceKm(double lat1, double lon1, double lat2, double lon2) {
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

class TripRecord {
  const TripRecord({
    this.id,
    required this.pickup,
    required this.dropoff,
    required this.price,
    required this.date,
    required this.truckType,
    required this.comment,
    required this.rating,
    this.cancelled = false,
    this.cancellationReason = '',
    this.goodTraits = const [],
    this.badTraits = const [],
  });

  final String? id;
  final String pickup;
  final String dropoff;
  final double price;
  final DateTime date;
  final TruckType truckType;
  final String comment;
  final int rating;
  final bool cancelled;
  final String cancellationReason;

  /// Localized labels chosen at rating time.
  final List<String> goodTraits;
  final List<String> badTraits;
}

class AppState {
  const AppState({
    this.initialized = false,
    this.seenOnboarding = false,
    this.isLoggedIn = false,
    this.phone = '',
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.profileImageUrl = '',
    this.profilePhotoPath = '',
    this.profileSetupComplete = false,
    this.notificationsEnabled = true,
    this.locale = const Locale('ar'),
    this.pickup = '',
    this.dropoff = '',
    this.pickupLat = 0.0,
    this.pickupLng = 0.0,
    this.dropoffLat = 0.0,
    this.dropoffLng = 0.0,
    this.pickupInServiceArea = false,
    this.dropoffInServiceArea = false,
    this.selectedTruck = TruckType.singleCabine,
    this.estimatedPrice = 0,
    this.tripStage = TripStage.idle,
    this.tripStartTime,
    this.tripEndTime,
    this.history = const [],
    this.currentTripId,
    this.currentTripStatus = '',
    this.driverName = '',
    this.driverPhone = '',
    this.driverPlate = '',
    this.driverVehicleColor = '',
    this.driverVehicleModel = '',
    this.driverLat,
    this.driverLng,
    this.routePoints = const [],
  });

  final bool initialized;
  final bool seenOnboarding;
  final bool isLoggedIn;
  final String phone;
  final String firstName;
  final String lastName;
  final String email;

  /// Optional avatar URL (e.g. from your backend). Empty shows initials placeholder.
  final String profileImageUrl;

  /// Local profile photo file path (device). Takes precedence over [profileImageUrl] when set.
  final String profilePhotoPath;

  /// First-time profile form after OTP has been completed.
  final bool profileSetupComplete;
  final bool notificationsEnabled;
  final Locale locale;
  final String pickup;
  final String dropoff;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final bool pickupInServiceArea;
  final bool dropoffInServiceArea;
  final TruckType selectedTruck;
  final double estimatedPrice;
  final TripStage tripStage;
  final List<LatLng> routePoints;

  /// Set when a transport request is created; cleared when the trip is reset.
  final DateTime? tripStartTime;

  /// Set when the trip reaches [TripStage.arrivedSummary] after end trip.
  final DateTime? tripEndTime;
  final List<TripRecord> history;

  /// Server-assigned trip ID for the active trip (used for cancel/rate API calls).
  final String? currentTripId;

  /// Latest API trip status string (requested, accepted, …).
  final String currentTripStatus;
  final String driverName;
  final String driverPhone;
  final String driverPlate;
  final String driverVehicleColor;
  final String driverVehicleModel;
  final double? driverLat;
  final double? driverLng;

  bool get hasDriverLocation => driverLat != null && driverLng != null;

  bool get canCancelActiveTrip =>
      currentTripStatus == 'requested' || currentTripStatus == 'accepted';

  bool get canCreateTransportRequest =>
      pickupInServiceArea && dropoffInServiceArea;

  bool get hasActiveTrip => tripStage != TripStage.idle;

  AppState copyWith({
    bool? initialized,
    bool? seenOnboarding,
    bool? isLoggedIn,
    String? phone,
    String? firstName,
    String? lastName,
    String? email,
    String? profileImageUrl,
    String? profilePhotoPath,
    bool? profileSetupComplete,
    bool? notificationsEnabled,
    Locale? locale,
    String? pickup,
    String? dropoff,
    double? pickupLat,
    double? pickupLng,
    double? dropoffLat,
    double? dropoffLng,
    bool? pickupInServiceArea,
    bool? dropoffInServiceArea,
    TruckType? selectedTruck,
    double? estimatedPrice,
    TripStage? tripStage,
    DateTime? tripStartTime,
    DateTime? tripEndTime,
    bool tripStartTimeNull = false,
    bool tripEndTimeNull = false,
    List<TripRecord>? history,
    String? currentTripId,
    bool currentTripIdNull = false,
    String? currentTripStatus,
    String? driverName,
    String? driverPhone,
    String? driverPlate,
    String? driverVehicleColor,
    String? driverVehicleModel,
    double? driverLat,
    double? driverLng,
    bool clearDriverLocation = false,
    List<LatLng>? routePoints,
  }) {
    return AppState(
      initialized: initialized ?? this.initialized,
      seenOnboarding: seenOnboarding ?? this.seenOnboarding,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      phone: phone ?? this.phone,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
      profileSetupComplete: profileSetupComplete ?? this.profileSetupComplete,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      locale: locale ?? this.locale,
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      dropoffLat: dropoffLat ?? this.dropoffLat,
      dropoffLng: dropoffLng ?? this.dropoffLng,
      pickupInServiceArea: pickupInServiceArea ?? this.pickupInServiceArea,
      dropoffInServiceArea: dropoffInServiceArea ?? this.dropoffInServiceArea,
      selectedTruck: selectedTruck ?? this.selectedTruck,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      tripStage: tripStage ?? this.tripStage,
      tripStartTime: tripStartTimeNull
          ? null
          : (tripStartTime ?? this.tripStartTime),
      tripEndTime: tripEndTimeNull ? null : (tripEndTime ?? this.tripEndTime),
      history: history ?? this.history,
      currentTripId: currentTripIdNull
          ? null
          : (currentTripId ?? this.currentTripId),
      currentTripStatus: currentTripStatus ?? this.currentTripStatus,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      driverPlate: driverPlate ?? this.driverPlate,
      driverVehicleColor: driverVehicleColor ?? this.driverVehicleColor,
      driverVehicleModel: driverVehicleModel ?? this.driverVehicleModel,
      driverLat: clearDriverLocation ? null : (driverLat ?? this.driverLat),
      driverLng: clearDriverLocation ? null : (driverLng ?? this.driverLng),
      routePoints: routePoints ?? this.routePoints,
    );
  }
}

final appStateProvider = NotifierProvider<AppStateNotifier, AppState>(
  AppStateNotifier.new,
);

class AppStateNotifier extends Notifier<AppState> {
  Timer? _tripTimer;
  Timer? _pollTimer;
  Timer? _fareDebounceTimer;
  late final ApiClient _apiClient;
  TripSocketService? _tripSocket;

  @override
  AppState build() {
    _apiClient = ref.read(apiClientProvider);
    ref.onDispose(() {
      _tripTimer?.cancel();
      _pollTimer?.cancel();
      _fareDebounceTimer?.cancel();
      unawaited(_tripSocket?.disconnect());
    });
    return const AppState();
  }

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seenOnboarding') ?? false;
    final loggedIn = prefs.getBool('loggedIn') ?? false;
    final phone = prefs.getString('phone') ?? '';
    final firstName = prefs.getString('firstName') ?? '';
    final lastName = prefs.getString('lastName') ?? '';
    final email = prefs.getString('email') ?? '';
    final profileImageUrl = prefs.getString('profileImageUrl') ?? '';
    final profilePhotoPath = prefs.getString('profilePhotoPath') ?? '';
    final lang = prefs.getString('lang') ?? 'ar';
    final notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;

    var profileSetupComplete = prefs.getBool('profileSetupComplete');
    if (profileSetupComplete == null &&
        firstName.trim().isNotEmpty &&
        lastName.trim().isNotEmpty) {
      profileSetupComplete = true;
      await prefs.setBool('profileSetupComplete', true);
    }
    profileSetupComplete ??= false;

    List<TripRecord> history = [];
    if (loggedIn) {
      try {
        history = await _fetchTripHistory();
        await _syncUserFromServer();
      } catch (_) {
        history = [];
      }
    }

    state = state.copyWith(
      initialized: false,
      seenOnboarding: seen,
      isLoggedIn: loggedIn,
      phone: phone,
      firstName: firstName,
      lastName: lastName,
      email: email,
      profileImageUrl: profileImageUrl,
      profilePhotoPath: profilePhotoPath,
      profileSetupComplete: profileSetupComplete,
      notificationsEnabled: notificationsEnabled,
      locale: Locale(lang),
      history: history,
    );
    if (loggedIn) {
      await resumeActiveTripIfAny();
    }
    state = state.copyWith(initialized: true);
    _refreshFareEstimate();
  }

  /// Refetch active trip from API, restore UI state, reconnect socket/poll.
  Future<void> resumeActiveTripIfAny() async {
    await _resumeActiveTrip();
  }

  Future<void> _syncUserFromServer() async {
    try {
      final res = await _apiClient.get<Map<String, dynamic>>('/users/me');
      final user = res.data;
      if (user == null) return;
      final name = (user['name'] as String? ?? '').trim();
      final parts = name.split(' ');
      final fn = parts.isNotEmpty ? parts.first : '';
      final ln = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      final complete = user['profileComplete'] as bool? ?? false;
      final avatar = user['avatarUrl'] as String? ?? '';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('firstName', fn);
      await prefs.setString('lastName', ln);
      await prefs.setBool('profileSetupComplete', complete);
      if (avatar.isNotEmpty) {
        await prefs.setString('profileImageUrl', avatar);
      }
      state = state.copyWith(
        firstName: fn,
        lastName: ln,
        profileSetupComplete: complete,
        profileImageUrl: avatar.isNotEmpty ? avatar : state.profileImageUrl,
      );
    } catch (_) {}
  }

  /// Sends OTP to the given phone number via the API.
  /// Throws [DioException] on failure.
  Future<void> sendOtp(String phone) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/auth/otp/send',
      data: {'phone': phone, 'role': 'client'},
    );
  }

  /// Verifies OTP and logs the user in. Returns `true` on success.
  Future<bool> verifyOtp(String phone, String otp) async {
    try {
      final res = await _apiClient.post<Map<String, dynamic>>(
        '/auth/otp/verify',
        data: {'phone': phone, 'otp': otp, 'role': 'client'},
      );
      final data = res.data;
      if (data == null) return false;
      final accessToken = data['accessToken'] as String?;
      final refreshToken = data['refreshToken'] as String?;
      final user = data['user'] as Map<String, dynamic>?;
      if (accessToken == null) return false;
      await _apiClient.saveTokens(accessToken, refreshToken ?? '');
      final profileComplete = user?['profileComplete'] as bool? ?? false;
      await loginWithPhone(phone, profileSetupComplete: profileComplete);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);
    state = state.copyWith(seenOnboarding: true);
  }

  Future<void> loginWithPhone(
    String phone, {
    String? firstName,
    String? lastName,
    String? email,
    String? profileImageUrl,
    String? profilePhotoPath,
    bool? profileSetupComplete,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final fn = firstName ?? prefs.getString('firstName') ?? '';
    final ln = lastName ?? prefs.getString('lastName') ?? '';
    final em = email ?? prefs.getString('email') ?? '';
    final url = profileImageUrl ?? prefs.getString('profileImageUrl') ?? '';
    final photoPath =
        profilePhotoPath ?? prefs.getString('profilePhotoPath') ?? '';

    bool complete;
    if (profileSetupComplete != null) {
      complete = profileSetupComplete;
    } else {
      var stored = prefs.getBool('profileSetupComplete');
      if (stored == null && fn.trim().isNotEmpty && ln.trim().isNotEmpty) {
        stored = true;
      }
      complete = stored ?? false;
    }

    await prefs.setString('phone', phone);
    await prefs.setBool('loggedIn', true);
    await prefs.setString('firstName', fn);
    await prefs.setString('lastName', ln);
    await prefs.setString('email', em);
    await prefs.setString('profileImageUrl', url);
    await prefs.setString('profilePhotoPath', photoPath);
    await prefs.setBool('profileSetupComplete', complete);

    List<TripRecord> history = [];
    try {
      history = await _fetchTripHistory();
    } catch (_) {}

    state = state.copyWith(
      isLoggedIn: true,
      phone: phone,
      firstName: fn,
      lastName: ln,
      email: em,
      profileImageUrl: url,
      profilePhotoPath: photoPath,
      profileSetupComplete: complete,
      history: history,
    );
  }

  Future<void> saveProfileSetup({
    required String firstName,
    required String lastName,
    required String email,
    String? profileImageUrl,
    String? profilePhotoPath,
  }) async {
    final name = '${firstName.trim()} ${lastName.trim()}'.trim();
    String? uploadedAvatarUrl;
    try {
      await _apiClient.post<Map<String, dynamic>>(
        '/users/me/profile-setup',
        data: {'name': name, 'locale': state.locale.languageCode},
      );
      if (profilePhotoPath != null && profilePhotoPath.isNotEmpty) {
        final bytes = await File(profilePhotoPath).readAsBytes();
        final filename = profilePhotoPath.split('/').last;
        final res = await _apiClient.uploadFile<Map<String, dynamic>>(
          '/users/me/avatar',
          'file',
          bytes,
          filename,
        );
        uploadedAvatarUrl = res.data?['avatarUrl'] as String?;
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('firstName', firstName.trim());
    await prefs.setString('lastName', lastName.trim());
    await prefs.setString('email', email.trim());
    await prefs.setBool('profileSetupComplete', true);
    if (profileImageUrl != null) {
      await prefs.setString('profileImageUrl', profileImageUrl.trim());
    }
    if (profilePhotoPath != null) {
      final p = profilePhotoPath.trim();
      if (p.isEmpty) {
        await prefs.remove('profilePhotoPath');
      } else {
        await prefs.setString('profilePhotoPath', p);
      }
    }
    state = state.copyWith(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      email: email.trim(),
      profileSetupComplete: true,
      profileImageUrl:
          uploadedAvatarUrl?.trim() ??
          profileImageUrl?.trim() ??
          state.profileImageUrl,
      profilePhotoPath: profilePhotoPath != null
          ? profilePhotoPath.trim()
          : state.profilePhotoPath,
    );
    await _syncUserFromServer();
  }

  Future<void> updateCustomerProfile({
    String? firstName,
    String? lastName,
    String? email,
  }) async {
    await saveProfileSetup(
      firstName: firstName ?? state.firstName,
      lastName: lastName ?? state.lastName,
      email: email ?? state.email,
    );
  }

  Future<void> uploadProfilePhoto(String localPath) async {
    final path = localPath.trim();
    if (path.isEmpty) return;
    try {
      final bytes = await File(path).readAsBytes();
      final filename = path.split('/').last;
      final res = await _apiClient.uploadFile<Map<String, dynamic>>(
        '/users/me/avatar',
        'file',
        bytes,
        filename,
      );
      final avatarUrl = res.data?['avatarUrl'] as String? ?? '';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profilePhotoPath', path);
      if (avatarUrl.isNotEmpty) {
        await prefs.setString('profileImageUrl', avatarUrl);
      }
      state = state.copyWith(
        profilePhotoPath: path,
        profileImageUrl: avatarUrl.isNotEmpty
            ? avatarUrl
            : state.profileImageUrl,
      );
    } catch (_) {}
  }

  Future<void> logout() async {
    await _teardownActiveTrip();
    try {
      await _apiClient.post<void>('/auth/logout');
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('loggedIn', false);
    await _apiClient.clearTokens();
    state = state.copyWith(isLoggedIn: false);
  }

  /// Clears saved account data on this device and signs out.
  Future<void> deleteAccount() async {
    await _teardownActiveTrip();
    try {
      await _apiClient.delete('/users/me');
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('phone');
    await prefs.remove('firstName');
    await prefs.remove('lastName');
    await prefs.remove('email');
    await prefs.remove('profileImageUrl');
    await prefs.remove('profilePhotoPath');
    await prefs.remove('profileSetupComplete');
    await prefs.setBool('loggedIn', false);
    await _apiClient.clearTokens();
    state = state.copyWith(
      isLoggedIn: false,
      phone: '',
      firstName: '',
      lastName: '',
      email: '',
      profileImageUrl: '',
      profilePhotoPath: '',
      profileSetupComplete: false,
      history: [],
    );
  }

  Future<void> setLocale(Locale locale) async {
    final code = locale.languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', code);
    state = state.copyWith(locale: Locale(code));
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', enabled);
    state = state.copyWith(notificationsEnabled: enabled);
  }

  void setPickupPlace({
    required String label,
    required double lat,
    required double lng,
    required bool inServiceArea,
  }) {
    state = state.copyWith(
      pickup: label,
      pickupLat: lat,
      pickupLng: lng,
      pickupInServiceArea: inServiceArea,
    );
    _refreshFareEstimate();
    _refreshRoutePoints();
  }

  void setDropoffPlace({
    required String label,
    required double lat,
    required double lng,
    required bool inServiceArea,
  }) {
    state = state.copyWith(
      dropoff: label,
      dropoffLat: lat,
      dropoffLng: lng,
      dropoffInServiceArea: inServiceArea,
    );
    _refreshFareEstimate();
    _refreshRoutePoints();
  }

  Future<void> _refreshRoutePoints() async {
    if (state.pickupLat == 0.0 ||
        state.pickupLng == 0.0 ||
        state.dropoffLat == 0.0 ||
        state.dropoffLng == 0.0) {
      state = state.copyWith(routePoints: const []);
      return;
    }
    try {
      final places = ref.read(placesServiceProvider);
      final points = await places.fetchDirections(
        originLat: state.pickupLat,
        originLng: state.pickupLng,
        destLat: state.dropoffLat,
        destLng: state.dropoffLng,
      );
      state = state.copyWith(routePoints: points);
    } catch (_) {
      // Fallback to straight line with midpoint
      final p = LatLng(state.pickupLat, state.pickupLng);
      final d = LatLng(state.dropoffLat, state.dropoffLng);
      final mid = LatLng(
        (p.latitude + d.latitude) / 2,
        (p.longitude + d.longitude) / 2,
      );
      state = state.copyWith(routePoints: [p, mid, d]);
    }
  }

  void setTruckType(TruckType type) {
    state = state.copyWith(selectedTruck: type);
    _refreshFareEstimate();
  }

  void _refreshFareEstimate() {
    _fareDebounceTimer?.cancel();
    _fareDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_refreshFareEstimateFromApi());
    });
  }

  Future<void> _teardownActiveTrip() async {
    _pollTimer?.cancel();
    _tripTimer?.cancel();
    final tripId = state.currentTripId;
    if (tripId != null && tripId.isNotEmpty) {
      _tripSocket?.leaveTrip(tripId);
    }
    await _tripSocket?.disconnect();
    state = state.copyWith(
      tripStage: TripStage.idle,
      tripStartTimeNull: true,
      tripEndTimeNull: true,
      currentTripIdNull: true,
      currentTripStatus: '',
      driverName: '',
      driverPhone: '',
      driverPlate: '',
      driverVehicleColor: '',
      driverVehicleModel: '',
      clearDriverLocation: true,
      pickup: '',
      dropoff: '',
      pickupLat: 0.0,
      pickupLng: 0.0,
      dropoffLat: 0.0,
      dropoffLng: 0.0,
      pickupInServiceArea: false,
      dropoffInServiceArea: false,
      estimatedPrice: 0,
      routePoints: const [],
      // Reset truck type to default so the next booking starts fresh.
      selectedTruck: TruckType.singleCabine,
    );
  }

  Future<void> _refreshFareEstimateFromApi() async {
    if (!state.isLoggedIn) return;
    if (state.pickupLat == 0.0 ||
        state.pickupLng == 0.0 ||
        state.dropoffLat == 0.0 ||
        state.dropoffLng == 0.0) {
      state = state.copyWith(estimatedPrice: 0);
      return;
    }
    try {
      final truckType = state.selectedTruck == TruckType.singleCabine
          ? 'single_cabin'
          : 'double_cabin';
      final res = await _apiClient.post<Map<String, dynamic>>(
        '/trips/estimate',
        data: {
          'pickup': {
            'lat': state.pickupLat,
            'lng': state.pickupLng,
            'address': state.pickup,
          },
          'dropoff': {
            'lat': state.dropoffLat,
            'lng': state.dropoffLng,
            'address': state.dropoff,
          },
          'truckType': truckType,
        },
      );
      final fare = (res.data?['fare'] as num?)?.toDouble();
      if (fare != null) {
        state = state.copyWith(estimatedPrice: fare);
        return;
      }
    } catch (_) {}
    final km = tripRouteDistanceKm(
      state.pickupLat,
      state.pickupLng,
      state.dropoffLat,
      state.dropoffLng,
    );
    state = state.copyWith(estimatedPrice: estimateFareDzd(km));
  }

  void _handleNoDriversFound() {
    _pollTimer?.cancel();
    final tripId = state.currentTripId;
    if (tripId != null && tripId.isNotEmpty) {
      _tripSocket?.leaveTrip(tripId);
    }
    state = state.copyWith(
      tripStage: TripStage.noDriversFound,
      tripStartTimeNull: true,
      currentTripIdNull: true,
      currentTripStatus: 'cancelled',
      driverName: '',
      driverPhone: '',
      driverPlate: '',
      driverVehicleColor: '',
      driverVehicleModel: '',
      clearDriverLocation: true,
    );
  }

  void dismissNoDriversFound() {
    _pollTimer?.cancel();
    _tripTimer?.cancel();
    final tripId = state.currentTripId;
    if (tripId != null && tripId.isNotEmpty) {
      _tripSocket?.leaveTrip(tripId);
    }
    state = state.copyWith(
      tripStage: TripStage.idle,
      tripStartTimeNull: true,
      currentTripIdNull: true,
      currentTripStatus: '',
      driverName: '',
      driverPhone: '',
      driverPlate: '',
      driverVehicleColor: '',
      driverVehicleModel: '',
      clearDriverLocation: true,
    );
  }

  Future<void> _ensureTripSocket(String tripId) async {
    _tripSocket ??= TripSocketService(_apiClient);
    await _tripSocket!.connect(
      onDriverAssigned: (data) {
        final driver = data['driver'];
        final merged = Map<String, dynamic>.from(data);
        merged['status'] = data['status'] as String? ?? 'accepted';
        if (driver is Map) {
          merged['driver'] = Map<String, dynamic>.from(driver);
        }
        _applyTripData(merged);
      },
      onStatusChanged: (data) {
        final reason =
            data['cancelledReason'] as String? ??
            data['reason'] as String? ??
            '';
        if (reason == 'no_drivers_found') {
          _handleNoDriversFound();
          return;
        }
        _applyTripData(data);
      },
      onNoDrivers: (_) => _handleNoDriversFound(),
      onDriverLocation: (data) {
        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) return;
        state = state.copyWith(driverLat: lat, driverLng: lng);
      },
    );
    await _tripSocket!.joinTrip(tripId);
  }

  String? _parseCreatedTripId(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final trip = map['trip'];
    if (trip is Map) {
      final nested = Map<String, dynamic>.from(trip);
      final id = nested['id'] ?? nested['_id'];
      if (id != null) return id.toString();
    }
    final top = map['id'] ?? map['_id'];
    if (top != null) return top.toString();
    return null;
  }

  void _applyTripLocationsFromPayload(Map<String, dynamic> data) {
    final pickup = data['pickup'] as Map<String, dynamic>?;
    final dropoff = data['dropoff'] as Map<String, dynamic>?;
    // NOTE: Do NOT read truckType here — it belongs to the trip/driver and
    // would silently overwrite the user's own truck-type selection every time
    // a poll or socket event arrives. Truck type is set only at trip-resume
    // time (before the state reset in _resumeActiveTrip) and during
    // _applyTripData when the driver's vehicle type is known.
    state = state.copyWith(
      pickup: pickup?['address'] as String? ?? state.pickup,
      pickupLat: (pickup?['lat'] as num?)?.toDouble() ?? state.pickupLat,
      pickupLng: (pickup?['lng'] as num?)?.toDouble() ?? state.pickupLng,
      dropoff: dropoff?['address'] as String? ?? state.dropoff,
      dropoffLat: (dropoff?['lat'] as num?)?.toDouble() ?? state.dropoffLat,
      dropoffLng: (dropoff?['lng'] as num?)?.toDouble() ?? state.dropoffLng,
      pickupInServiceArea: true,
      dropoffInServiceArea: true,
    );
  }

  Future<bool> _resumeActiveTrip() async {
    try {
      final res = await _apiClient.get<Map<String, dynamic>>(
        '/users/me/active-trip',
      );
      final tripRaw = res.data?['trip'];
      if (tripRaw is! Map) return false;
      final data = Map<String, dynamic>.from(tripRaw);

      final tripId = data['id'] as String? ?? data['_id'] as String? ?? '';
      if (tripId.isEmpty) return false;

      final status = data['status'] as String? ?? 'requested';
      final cancelledReason = data['cancelledReason'] as String? ?? '';
      if (status == 'cancelled' && cancelledReason == 'no_drivers_found') {
        _handleNoDriversFound();
        return true;
      }

      // ─── Guard: trip already rated ─────────────────────────────────────────
      // If the driver has been rated, the user has fully completed this trip.
      // Do not re-trigger any trip UI — just return without touching state.
      final alreadyRated = data['driverRating'] != null;
      if (alreadyRated) {
        // If somehow the state wasn't cleaned up (e.g. app killed mid-teardown),
        // force a teardown now so the router doesn't redirect to /trip.
        if (state.tripStage != TripStage.idle) {
          unawaited(_teardownActiveTrip());
        }
        return false;
      }
      // ───────────────────────────────────────────────────────────────────────

      // ─── Guard: post-trip race condition ───────────────────────────────────
      // After submitRating() tears down state (tripStage → idle), the app
      // lifecycle may fire resumeActiveTripIfAny() before the backend has
      // persisted the driverRating (so alreadyRated is still false above).
      // If we are already idle and the trip is in a terminal post-ride
      // status (awaitingCash / completed), there is nothing to resume —
      // the cleanup already happened on the client side.
      if (state.tripStage == TripStage.idle &&
          (status == 'awaitingCash' || status == 'completed')) {
        return false;
      }
      // ───────────────────────────────────────────────────────────────────────

      // ─── Guard: already showing the post-trip summary ──────────────────────
      // didChangeAppLifecycleState calls this every time the app resumes.
      // If the client is already on the arrivedSummary screen, skip the
      // destructive tripStage reset (which would flash the map) and just
      // silently re-apply the fresh data.
      if (state.tripStage == TripStage.arrivedSummary) {
        _applyTripData(data);
        return true;
      }
      // ───────────────────────────────────────────────────────────────────────

      final fare =
          (data['finalFare'] as num?)?.toDouble() ??
          (data['fare'] as num?)?.toDouble();
      final createdAt =
          DateTime.tryParse(data['createdAt'] as String? ?? '') ??
          DateTime.now();
      _applyTripLocationsFromPayload(data);
      state = state.copyWith(
        tripEndTimeNull: true,
        currentTripId: tripId,
        currentTripStatus: status,
        driverName: '',
        driverPhone: '',
        driverPlate: '',
        driverVehicleColor: '',
        driverVehicleModel: '',
        tripStage: TripStage.searchingDriver,
        tripStartTime: createdAt,
        estimatedPrice: fare ?? state.estimatedPrice,
      );
      _startTripPolling(tripId);
      try {
        await _ensureTripSocket(tripId);
      } catch (e) {
        debugPrint('[Tashila] resume trip socket failed: $e');
      }
      _applyTripData(data);
      return true;
    } catch (e) {
      debugPrint('[Tashila] resumeActiveTrip failed: $e');
      return false;
    }
  }

  Future<bool> createTransportRequest() async {
    if (!state.canCreateTransportRequest) return false;
    _tripTimer?.cancel();
    _pollTimer?.cancel();

    try {
      final truckType = state.selectedTruck == TruckType.singleCabine
          ? 'single_cabin'
          : 'double_cabin';
      final res = await _apiClient.post<Map<String, dynamic>>(
        '/trips',
        data: {
          'pickup': {
            'lat': state.pickupLat,
            'lng': state.pickupLng,
            'address': state.pickup,
          },
          'dropoff': {
            'lat': state.dropoffLat,
            'lng': state.dropoffLng,
            'address': state.dropoff,
          },
          'truckType': truckType,
          'paymentMethod': 'cash',
        },
      );
      var tripId = _parseCreatedTripId(res.data);
      if (tripId == null) {
        debugPrint('[Tashila] create trip missing id, body=${res.data}');
        return _resumeActiveTrip();
      }

      final tripPayload = res.data?['trip'];
      final tripMap = tripPayload is Map
          ? Map<String, dynamic>.from(tripPayload)
          : <String, dynamic>{};
      final dispatch = res.data?['dispatch'];
      final dispatchMap = dispatch is Map
          ? Map<String, dynamic>.from(dispatch)
          : <String, dynamic>{};
      final fare = (tripMap['fare'] as num?)?.toDouble();
      final tripStatus = tripMap['status'] as String? ?? 'requested';
      final cancelledReason = tripMap['cancelledReason'] as String? ?? '';
      final outcome = dispatchMap['outcome'] as String? ?? '';
      final nearby = (dispatchMap['nearbyDriversCount'] as num?)?.toInt() ?? -1;

      if (tripStatus == 'cancelled' &&
          (cancelledReason == 'no_drivers_found' ||
              outcome == 'no_drivers_found' ||
              nearby == 0)) {
        _handleNoDriversFound();
        return true;
      }

      state = state.copyWith(
        tripEndTimeNull: true,
        currentTripId: tripId,
        currentTripStatus: tripStatus,
        driverName: '',
        driverPhone: '',
        driverPlate: '',
        driverVehicleColor: '',
        driverVehicleModel: '',
        clearDriverLocation: true,
        tripStage: TripStage.searchingDriver,
        tripStartTime: DateTime.now(),
        estimatedPrice: fare ?? state.estimatedPrice,
        // Clear any stale route from the previous trip so the map on /trip
        // does not flicker with an old polyline before new routing is ready.
        routePoints: const [],
      );
      _startTripPolling(tripId);
      try {
        await _ensureTripSocket(tripId);
      } catch (e) {
        debugPrint('[Tashila] trip socket connect failed: $e');
      }
      return true;
    } on DioException catch (e) {
      debugPrint(
        '[Tashila] create trip HTTP error: '
        'status=${e.response?.statusCode} data=${e.response?.data}',
      );
      if (e.response?.statusCode == 401) {
        await logout();
        return false;
      }
      if (e.response?.statusCode == 409) {
        return _resumeActiveTrip();
      }
      final recovered = await _resumeActiveTrip();
      if (recovered) return true;
      state = state.copyWith(
        tripStage: TripStage.idle,
        tripStartTimeNull: true,
        currentTripIdNull: true,
        currentTripStatus: '',
      );
      return false;
    }
  }

  /// Used by widget tests only — simulates driver progression without API.
  @visibleForTesting
  void applyTripDataForTesting(Map<String, dynamic> data) =>
      _applyTripData(data);

  /// Used by widget tests only — simulates driver progression without API.
  @visibleForTesting
  void simulateTripForTesting() {
    state = state.copyWith(
      tripStage: TripStage.searchingDriver,
      tripStartTime: DateTime.now(),
      currentTripStatus: 'requested',
    );
    _startSimulatedTrip();
  }

  void _startSimulatedTrip() {
    var tick = 0;
    _tripTimer = Timer.periodic(const Duration(seconds: 4), (t) {
      tick++;
      if (tick == 1 && state.tripStage == TripStage.searchingDriver) {
        state = state.copyWith(tripStage: TripStage.driverEnRoute);
      } else if (tick == 2 && state.tripStage == TripStage.driverEnRoute) {
        state = state.copyWith(tripStage: TripStage.tripStarted);
      } else if (tick == 3 && state.tripStage == TripStage.tripStarted) {
        endTrip();
        t.cancel();
      }
    });
  }

  void _startTripPolling(String tripId) {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final res = await _apiClient.get<Map<String, dynamic>>(
          '/trips/$tripId',
        );
        final data = res.data;
        if (data == null) return;
        _applyTripData(data);
      } catch (_) {}
    });
  }

  void _applyTripData(Map<String, dynamic> data) {
    if (state.tripStage == TripStage.idle) {
      // If the client has already rated the driver and returned to the home screen (idle stage),
      // ignore any late in-flight poll responses or socket messages for the completed trip.
      return;
    }
    _applyTripLocationsFromPayload(data);
    final status = data['status'] as String? ?? '';
    final driver = data['driver'] as Map<String, dynamic>?;
    final fare =
        (data['finalFare'] as num?)?.toDouble() ??
        (data['fare'] as num?)?.toDouble();
    final plate =
        driver?['vehiclePlate'] as String? ??
        data['vehiclePlate'] as String? ??
        state.driverPlate;
    final color =
        driver?['vehicleColor'] as String? ??
        data['vehicleColor'] as String? ??
        state.driverVehicleColor;
    final model =
        driver?['vehicleModel'] as String? ??
        data['vehicleModel'] as String? ??
        state.driverVehicleModel;
    final driverTruck = driver?['truckType'] as String?;
    TruckType? truckFromDriver;
    if (driverTruck == 'double_cabin') {
      truckFromDriver = TruckType.doubleCabine;
    } else if (driverTruck == 'single_cabin') {
      truckFromDriver = TruckType.singleCabine;
    }

    // Parse server-authoritative timestamps (sent by backend when status changes).
    final startedAtRaw = data['startedAt'] as String?;
    final completedAtRaw = data['completedAt'] as String?;
    final startedAt = startedAtRaw != null
        ? DateTime.tryParse(startedAtRaw)?.toLocal()
        : null;
    final completedAt = completedAtRaw != null
        ? DateTime.tryParse(completedAtRaw)?.toLocal()
        : null;

    state = state.copyWith(
      currentTripStatus: status,
      driverName: driver?['name'] as String? ?? state.driverName,
      driverPhone: driver?['phone'] as String? ?? state.driverPhone,
      driverPlate: plate,
      driverVehicleColor: color,
      driverVehicleModel: model,
      selectedTruck: truckFromDriver ?? state.selectedTruck,
      estimatedPrice: fare ?? state.estimatedPrice,
    );

    switch (status) {
      case 'requested':
        if (state.tripStage == TripStage.idle) {
          state = state.copyWith(tripStage: TripStage.searchingDriver);
        }
      case 'accepted':
      case 'headingToPickup':
        if (state.tripStage == TripStage.searchingDriver) {
          state = state.copyWith(
            tripStage: TripStage.driverEnRoute,
            clearDriverLocation: true,
          );
        }
      case 'inProgress':
        // Use server startedAt for accurate trip start time.
        if (startedAt != null) {
          state = state.copyWith(tripStartTime: startedAt);
        }
        if (state.tripStage != TripStage.tripStarted &&
            state.tripStage != TripStage.awaitingPayment &&
            state.tripStage != TripStage.arrivedSummary) {
          state = state.copyWith(tripStage: TripStage.tripStarted);
        }
      case 'awaitingCash':
        if (state.tripStage != TripStage.arrivedSummary) {
          endTrip(
            finalFare: fare,
            serverStartedAt: startedAt,
            serverCompletedAt: completedAt,
          );
        }
      case 'completed':
        _pollTimer?.cancel();
        final alreadyRated = data['driverRating'] != null;
        if (alreadyRated) {
          if (state.tripStage != TripStage.idle) {
            unawaited(_finalizeCompletedTripFromServer(data, fare: fare));
          }
          break;
        }
        if (state.tripStage != TripStage.arrivedSummary) {
          endTrip(
            finalFare: fare,
            serverStartedAt: startedAt,
            serverCompletedAt: completedAt,
          );
        }
      case 'cancelled':
        _pollTimer?.cancel();
        if (state.tripStage == TripStage.arrivedSummary) break;
        final reason = data['cancelledReason'] as String? ?? '';
        if (reason == 'no_drivers_found') {
          _handleNoDriversFound();
          break;
        }
        if (state.tripStage != TripStage.idle &&
            state.tripStage != TripStage.noDriversFound) {
          unawaited(_teardownActiveTrip());
        }
    }
  }

  Future<List<TripRecord>> _fetchTripHistory() async {
    try {
      final res = await _apiClient.get<Map<String, dynamic>>(
        '/users/me/trips?limit=50&page=1',
      );
      final items = (res.data?['items'] as List<dynamic>?) ?? [];
      return items.map((item) {
        final m = item as Map<String, dynamic>;
        final pickup = m['pickup'] as Map<String, dynamic>? ?? {};
        final dropoff = m['dropoff'] as Map<String, dynamic>? ?? {};
        final truckType = (m['truckType'] as String?) == 'double_cabin'
            ? TruckType.doubleCabine
            : TruckType.singleCabine;
        final cancelled = (m['status'] as String?) == 'cancelled';
        return TripRecord(
          id: m['id'] as String? ?? m['_id'] as String? ?? '',
          pickup:
              pickup['address'] as String? ??
              '${pickup['lat']},${pickup['lng']}',
          dropoff:
              dropoff['address'] as String? ??
              '${dropoff['lat']},${dropoff['lng']}',
          price: ((m['finalFare'] as num?) ?? (m['fare'] as num?) ?? 0)
              .toDouble(),
          date:
              DateTime.tryParse(m['createdAt'] as String? ?? '') ??
              DateTime.now(),
          truckType: truckType,
          comment: '',
          rating: (m['driverRating'] as int?) ?? 0,
          cancelled: cancelled,
          cancellationReason: m['cancelledReason'] as String? ?? '',
          goodTraits: const [],
          badTraits: const [],
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Delivery leg finished — moves to [TripStage.arrivedSummary].
  ///
  /// [serverStartedAt] and [serverCompletedAt] are the authoritative UTC timestamps
  /// from the backend. When provided they override the client-side approximations.
  void endTrip({
    double? finalFare,
    DateTime? serverStartedAt,
    DateTime? serverCompletedAt,
  }) {
    if (state.tripStage == TripStage.idle ||
        state.tripStage == TripStage.noDriversFound ||
        state.tripStage == TripStage.arrivedSummary) {
      return;
    }
    // Stop polling — we no longer need live status once the summary is shown.
    _pollTimer?.cancel();
    _pollTimer = null;
    // Prefer server timestamp; fall back to what we have in state, then now().
    final start = serverStartedAt ?? state.tripStartTime;
    final end = serverCompletedAt ?? DateTime.now();
    final minutes = start != null
        ? end.difference(start).inMinutes.toDouble()
        : 0.0;
    final km = tripRouteDistanceKm(
      state.pickupLat,
      state.pickupLng,
      state.dropoffLat,
      state.dropoffLng,
    );
    final computedFare = estimateFareDzd(km, tripMinutes: minutes);
    state = state.copyWith(
      tripStage: TripStage.arrivedSummary,
      // Update tripStartTime to the authoritative server value if provided.
      tripStartTime: serverStartedAt ?? state.tripStartTime,
      tripEndTime: end,
      tripEndTimeNull: false,
      estimatedPrice:
          finalFare ??
          (state.estimatedPrice > 0 ? state.estimatedPrice : computedFare),
    );
  }

  void resetTrip() {
    unawaited(_teardownActiveTrip());
  }

  /// After a driver is assigned; [reasonKey] is a stable API key (e.g. `changed_plans`).
  Future<bool> cancelTripWithReason(String reasonKey) async {
    if (!state.canCancelActiveTrip) return false;
    final tripId = state.currentTripId;
    if (tripId != null) {
      try {
        await _apiClient.delete(
          '/trips/$tripId',
          queryParameters: {'reason': reasonKey},
        );
      } catch (_) {
        return false;
      }
    }
    final record = TripRecord(
      id: tripId,
      pickup: state.pickup,
      dropoff: state.dropoff,
      price: state.estimatedPrice,
      date: DateTime.now(),
      truckType: state.selectedTruck,
      comment: '',
      rating: 0,
      cancelled: true,
      cancellationReason: reasonKey,
      goodTraits: const [],
      badTraits: const [],
    );
    await _teardownActiveTrip();
    state = state.copyWith(history: [record, ...state.history]);
    return true;
  }

  Future<void> completeRatingSession() async {
    if (state.tripStage != TripStage.arrivedSummary) return;
    await _teardownActiveTrip();
    _refreshFareEstimate();
  }

  Future<void> _finalizeCompletedTripFromServer(
    Map<String, dynamic> data, {
    double? fare,
  }) async {
    final tripId = data['id'] as String? ?? data['_id'] as String? ?? '';
    final tripPrice =
        fare ??
        (data['finalFare'] as num?)?.toDouble() ??
        (data['fare'] as num?)?.toDouble() ??
        (state.estimatedPrice > 0 ? state.estimatedPrice : kEstimatedTripPrice);
    final record = TripRecord(
      id: tripId,
      pickup: state.pickup,
      dropoff: state.dropoff,
      price: tripPrice,
      date:
          DateTime.tryParse(data['createdAt'] as String? ?? '') ??
          DateTime.now(),
      truckType: state.selectedTruck,
      comment: data['driverRatingComment'] as String? ?? '',
      rating: (data['driverRating'] as num?)?.toInt() ?? 0,
      cancelled: false,
      cancellationReason: '',
      goodTraits: const [],
      badTraits: const [],
    );
    final exists = state.history.any(
      (r) => r.id == tripId && tripId.isNotEmpty,
    );
    if (exists) {
      final list = state.history
          .map((r) => r.id == tripId ? record : r)
          .toList();
      state = state.copyWith(history: list);
    } else {
      state = state.copyWith(history: [record, ...state.history]);
    }
    await _teardownActiveTrip();
    _refreshFareEstimate();
  }

  Future<bool> submitRating({
    required int stars,
    required String comment,
    List<String> goodTraits = const [],
    List<String> badTraits = const [],
  }) async {
    if (stars < 1) return false;
    if (state.tripStage == TripStage.arrivedSummary) {
      final tripId = state.currentTripId;
      final fullComment = formatRatingComment(comment, goodTraits, badTraits);
      if (tripId != null && stars > 0) {
        try {
          await _apiClient.post<Map<String, dynamic>>(
            '/trips/$tripId/rate-driver',
            data: {
              'rating': stars,
              'comment': fullComment.isEmpty ? null : fullComment,
            },
          );
        } on DioException catch (e) {
          if (e.response?.statusCode != 409) {
            debugPrint(
              '[Tashila] rate driver failed: '
              'status=${e.response?.statusCode} data=${e.response?.data}',
            );
            return false;
          }
        } catch (e) {
          debugPrint('[Tashila] rate driver failed: $e');
          return false;
        }
      }
      final tripPrice = state.estimatedPrice > 0
          ? state.estimatedPrice
          : kEstimatedTripPrice;
      final record = TripRecord(
        id: tripId,
        pickup: state.pickup,
        dropoff: state.dropoff,
        price: tripPrice,
        date: DateTime.now(),
        truckType: state.selectedTruck,
        comment: fullComment,
        rating: stars,
        cancelled: false,
        cancellationReason: '',
        goodTraits: List<String>.from(goodTraits),
        badTraits: List<String>.from(badTraits),
      );
      final exists = state.history.any(
        (r) => r.id == tripId && tripId != null && tripId.isNotEmpty,
      );
      if (exists) {
        final list = state.history
            .map((r) => r.id == tripId ? record : r)
            .toList();
        state = state.copyWith(history: list);
      } else {
        state = state.copyWith(history: [record, ...state.history]);
      }
      // Tear down trip state immediately so that /home shows clean
      // pickup/dropoff fields and no stale route line. The caller
      // (rate_driver_screen._finish) no longer needs to call
      // completeRatingSession() separately.
      await _teardownActiveTrip();
      _refreshFareEstimate();
      return true;
    }
    if (state.history.isEmpty) return false;
    final first = state.history.first;
    final updated = TripRecord(
      id: first.id,
      pickup: first.pickup,
      dropoff: first.dropoff,
      price: first.price,
      date: first.date,
      truckType: first.truckType,
      comment: comment,
      rating: stars,
      cancelled: first.cancelled,
      cancellationReason: first.cancellationReason,
      goodTraits: List<String>.from(goodTraits),
      badTraits: List<String>.from(badTraits),
    );
    final list = [updated, ...state.history.skip(1)];
    state = state.copyWith(history: list);
    return true;
  }
}
