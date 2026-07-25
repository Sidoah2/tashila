import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tashila_driver/core/models/models.dart';
import 'package:tashila_driver/core/services/api_client.dart';
import 'package:tashila_driver/core/state/driver_app_state.dart';

import 'fake_repositories.dart';

Future<void> _waitForBootstrap(ProviderContainer container) async {
  for (var i = 0; i < 50; i++) {
    if (container.read(driverAppStateProvider).bootstrapped) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

class _TripNotAvailableRepository extends FakeTripRepository {
  const _TripNotAvailableRepository();

  @override
  Future<String?> acceptTrip(String tripId) async => 'TRIP_NOT_AVAILABLE';
}

class _ActiveTripWithClientRepository extends FakeTripRepository {
  const _ActiveTripWithClientRepository();

  @override
  Future<Map<String, dynamic>?> fetchActiveTrip() async => {
        'id': 'trip-42',
        'status': 'accepted',
        'client': {'name': 'Ali Client', 'phone': '+213555111222'},
        'pickup': {'address': 'Pickup A', 'lat': 36.7, 'lng': 3.1},
        'dropoff': {'address': 'Drop B', 'lat': 36.8, 'lng': 3.2},
        'fare': 1500,
        'distanceKm': 4.2,
      };
}

class _InProgressActiveTripRepository extends FakeTripRepository {
  const _InProgressActiveTripRepository();

  @override
  Future<Map<String, dynamic>?> fetchActiveTrip() async => {
        'id': 'trip-99',
        'status': 'inProgress',
        'client': {'name': 'Sam Client', 'phone': '+213555999000'},
        'pickup': {'address': 'Start', 'lat': 36.7, 'lng': 3.1},
        'dropoff': {'address': 'End', 'lat': 36.8, 'lng': 3.2},
        'fare': 2000,
        'distanceKm': 5.0,
      };
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('auto-login starts at home when profile is complete', () async {
    final completeProfile = DriverProfile(
      name: 'Driver One',
      phone: '+251900000000',
      truckType: kTruckSingleCabin,
      documentsApproved: true,
      documents: DocumentType.values
          .map(
            (type) => DriverDocument(
              type: type,
              fileName: '${type.name}.png',
              localFilePath: '/tmp/${type.name}.png',
              status: DocumentUploadStatus.uploaded,
            ),
          )
          .toList(),
    );

    SharedPreferences.setMockInitialValues({
      kSession: true,
      kSeenOnboarding: true,
      kProfileSetupComplete: true,
      kPhone: completeProfile.phone,
      kProfile: jsonEncode(completeProfile.toJson()),
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(driverAppStateProvider);
    await _waitForBootstrap(container);

    final state = container.read(driverAppStateProvider);
    expect(state.bootstrapped, isTrue);
    expect(state.isAuthenticated, isTrue);
    expect(state.profileSetupComplete, isTrue);
    expect(state.needsProfileSetup, isFalse);
    expect(state.startRoute, '/home');
  });

  test('server profileComplete without approval still blocks dashboard', () async {
    SharedPreferences.setMockInitialValues({
      kSession: true,
      kSeenOnboarding: true,
      kProfileSetupComplete: true,
      kPhone: '+251900000001',
      kProfile: jsonEncode(
        DriverProfile(
          name: 'Pending Driver',
          phone: '+251900000001',
          truckType: kTruckSingleCabin,
          documentsApproved: false,
          vehiclePlate: '12345',
          vehicleColor: 'White',
          vehicleModel: 'Hilux',
          documents: DocumentType.values
              .map(
                (type) => DriverDocument(
                  type: type,
                  fileName: '${type.name}.png',
                  remoteUrl: 'https://cdn.example/${type.name}.png',
                  status: DocumentUploadStatus.uploaded,
                ),
              )
              .toList(),
        ).toJson(),
      ),
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(driverAppStateProvider);
    await _waitForBootstrap(container);

    final state = container.read(driverAppStateProvider);
    expect(state.needsProfileSetup, isTrue);
    expect(state.startRoute, '/profile');
  });

  test('new driver without profileComplete needs signup', () async {
    SharedPreferences.setMockInitialValues({
      kSession: true,
      kSeenOnboarding: true,
      kProfileSetupComplete: false,
      kPhone: '+251900000002',
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(driverAppStateProvider);
    await _waitForBootstrap(container);

    final state = container.read(driverAppStateProvider);
    expect(state.needsProfileSetup, isTrue);
    expect(state.startRoute, '/profile');
  });

  test('trip transitions enforce status sequence', () async {
    SharedPreferences.setMockInitialValues({
      kSession: true,
      kSeenOnboarding: true,
      kAvailability: AvailabilityStatus.online.name,
    });

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(StubApiClient()),
        tripRepositoryProvider.overrideWithValue(const FakeTripRepository()),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(driverAppStateProvider.notifier);
    await _waitForBootstrap(container);

    await notifier.refreshNearbyRequests();

    final request =
        container.read(driverAppStateProvider).incomingOffers.first.request;
    expect(await notifier.acceptRequest(request), isTrue);

    await notifier.confirmArrivedAtClient();
    await notifier.completeTrip();

    expect(
      container.read(driverAppStateProvider).tripStatus,
      TripStatus.tripCompletedSummary,
    );
  });

  test('resume active trip loads client phone from API', () async {
    SharedPreferences.setMockInitialValues({
      kSession: true,
      kSeenOnboarding: true,
      kProfileSetupComplete: true,
      kPhone: '+213555000001',
    });

    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(
          const FakeProfileRepository(),
        ),
        tripRepositoryProvider.overrideWithValue(
          const _ActiveTripWithClientRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(driverAppStateProvider);
    await _waitForBootstrap(container);

    final request = container.read(driverAppStateProvider).currentRequest;
    expect(request, isNotNull);
    expect(request!.clientName, 'Ali Client');
    expect(request.clientPhone, '+213555111222');
    expect(
      container.read(driverAppStateProvider).tripStatus,
      TripStatus.headingToClient,
    );
  });

  test('resume active trip maps inProgress status', () async {
    SharedPreferences.setMockInitialValues({
      kSession: true,
      kSeenOnboarding: true,
      kProfileSetupComplete: true,
      kPhone: '+213555000002',
    });

    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(
          const FakeProfileRepository(),
        ),
        tripRepositoryProvider.overrideWithValue(
          const _InProgressActiveTripRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(driverAppStateProvider);
    await _waitForBootstrap(container);

    final state = container.read(driverAppStateProvider);
    expect(state.currentRequest?.id, 'trip-99');
    expect(state.tripStatus, TripStatus.tripInProgress);
    expect(state.hasActiveTrip, isTrue);
  });

  test('TRIP_NOT_AVAILABLE is treated as accept failure', () async {
    SharedPreferences.setMockInitialValues({
      kSession: true,
      kSeenOnboarding: true,
      kAvailability: AvailabilityStatus.online.name,
    });

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(StubApiClient()),
        tripRepositoryProvider.overrideWithValue(
          const _TripNotAvailableRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(driverAppStateProvider.notifier);
    await _waitForBootstrap(container);

    await notifier.refreshNearbyRequests();

    final request =
        container.read(driverAppStateProvider).incomingOffers.first.request;
    final accepted = await notifier.acceptRequest(request);

    expect(accepted, isFalse);
    expect(
      container.read(driverAppStateProvider).currentRequest,
      isNull,
    );
    expect(
      container.read(driverAppStateProvider).tripStatus,
      TripStatus.idle,
    );
    expect(
      container.read(driverAppStateProvider).incomingOffers,
      isEmpty,
    );
  });

  test('earnings summary reflects completed trip after payment', () async {
    SharedPreferences.setMockInitialValues({
      kSession: true,
      kSeenOnboarding: true,
      kAvailability: AvailabilityStatus.online.name,
    });

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(StubApiClient()),
        tripRepositoryProvider.overrideWithValue(const FakeTripRepository()),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(driverAppStateProvider.notifier);
    await _waitForBootstrap(container);

    await notifier.refreshNearbyRequests();

    final request =
        container.read(driverAppStateProvider).incomingOffers.first.request;
    await notifier.acceptRequest(request);
    await notifier.confirmArrivedAtClient();
    await notifier.completeTrip();
    await notifier.confirmCashReceived();
    await notifier.submitClientRatingAndFinish(rating: 5);

    final summary = notifier.earningsSummary;
    expect(summary.todayTrips, 1);
    expect(summary.todayTotal, request.fare);
  });
}
