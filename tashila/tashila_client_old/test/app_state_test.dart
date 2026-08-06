import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tashila_client/core/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('fare formula is same for single and double cabine', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(appStateProvider.notifier);
    notifier.setPickupPlace(label: 'A', lat: 36.722, lng: 3.182, inServiceArea: true);
    notifier.setDropoffPlace(label: 'B', lat: 36.746, lng: 3.050, inServiceArea: true);
    final s = container.read(appStateProvider);
    final km = tripRouteDistanceKm(s.pickupLat, s.pickupLng, s.dropoffLat, s.dropoffLng);
    final fare = estimateFareDzd(km);
    expect(fare, 1800);
    notifier.setTruckType(TruckType.singleCabine);
    notifier.setTruckType(TruckType.doubleCabine);
    expect(estimateFareDzd(km), fare);
  });

  test('submitRating rejects zero stars', () {
    FakeAsync().run((async) {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(appStateProvider.notifier);
      notifier.simulateTripForTesting();
      async.elapse(const Duration(seconds: 15));
      expect(container.read(appStateProvider).tripStage, TripStage.arrivedSummary);
      var done = false;
      var success = false;
      notifier.submitRating(stars: 0, comment: '').then((ok) {
        success = ok;
        done = true;
      });
      while (!done) {
        async.elapse(const Duration(milliseconds: 50));
      }
      expect(success, isFalse);
      expect(container.read(appStateProvider).history, isEmpty);
    });
  });

  test('submitting rating stores trip in history', () {
    FakeAsync().run((async) {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(appStateProvider.notifier);
      notifier.setPickupPlace(label: 'A', lat: 22.79, lng: 5.52, inServiceArea: true);
      notifier.setDropoffPlace(label: 'B', lat: 22.78, lng: 5.53, inServiceArea: true);
      notifier.simulateTripForTesting();
      async.elapse(const Duration(seconds: 5));
      expect(container.read(appStateProvider).tripStage, TripStage.driverEnRoute);
      async.elapse(const Duration(seconds: 5));
      expect(container.read(appStateProvider).tripStage, TripStage.tripStarted);
      async.elapse(const Duration(seconds: 5));
      expect(container.read(appStateProvider).tripStage, TripStage.arrivedSummary);
      var done = false;
      var success = false;
      notifier.submitRating(stars: 5, comment: 'Great').then((ok) {
        success = ok;
        done = true;
      });
      while (!done) {
        async.elapse(const Duration(milliseconds: 50));
      }
      expect(success, isTrue);
      expect(container.read(appStateProvider).history.length, 1);
      expect(container.read(appStateProvider).tripStage, TripStage.arrivedSummary);
      var finished = false;
      notifier.completeRatingSession().then((_) => finished = true);
      while (!finished) {
        async.elapse(const Duration(milliseconds: 50));
      }
      expect(container.read(appStateProvider).tripStage, TripStage.idle);
    });
  });

  test('driver contact fields populate from trip payload', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(appStateProvider.notifier);
    notifier.simulateTripForTesting();
    notifier.applyTripDataForTesting({
      'status': 'accepted',
      'driver': {
        'name': 'Driver Ali',
        'phone': '+213555333444',
        'vehiclePlate': 'DZ-1234',
        'vehicleColor': 'White',
        'vehicleModel': 'Toyota Hilux',
        'truckType': 'single_cabin',
      },
    });
    final state = container.read(appStateProvider);
    expect(state.driverName, 'Driver Ali');
    expect(state.driverPhone, '+213555333444');
    expect(state.driverPlate, 'DZ-1234');
    expect(state.driverVehicleColor, 'White');
    expect(state.driverVehicleModel, 'Toyota Hilux');
    expect(state.selectedTruck, TruckType.singleCabine);
    expect(state.tripStage, TripStage.driverEnRoute);
  });

  test('trip payload restores pickup dropoff and truck type', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(appStateProvider.notifier);
    notifier.simulateTripForTesting();
    notifier.applyTripDataForTesting({
      'status': 'accepted',
      'pickup': {'address': 'Pickup Ave', 'lat': 36.1, 'lng': 3.1},
      'dropoff': {'address': 'Drop St', 'lat': 36.2, 'lng': 3.2},
      'truckType': 'double_cabin',
      'driver': {
        'name': 'Driver Ali',
        'phone': '+213555333444',
        'vehiclePlate': 'DZ-1234',
      },
    });
    final state = container.read(appStateProvider);
    expect(state.pickup, 'Pickup Ave');
    expect(state.dropoff, 'Drop St');
    expect(state.pickupLat, 36.1);
    expect(state.dropoffLng, 3.2);
    expect(state.selectedTruck, TruckType.doubleCabine);
  });

  test('setPickupPlace updates label and coordinates', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(appStateProvider.notifier);
    notifier.setPickupPlace(label: 'Test Ave', lat: 36.0, lng: -1.0, inServiceArea: true);
    final s = container.read(appStateProvider);
    expect(s.pickup, 'Test Ave');
    expect(s.pickupLat, 36.0);
    expect(s.pickupLng, -1.0);
  });

  test('setDropoffPlace updates label and coordinates', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(appStateProvider.notifier);
    notifier.setDropoffPlace(label: 'Drop St', lat: 36.5, lng: -1.2, inServiceArea: true);
    final s = container.read(appStateProvider);
    expect(s.dropoff, 'Drop St');
    expect(s.dropoffLat, 36.5);
    expect(s.dropoffLng, -1.2);
  });
}
