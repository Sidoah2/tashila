import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tashila_client/core/config/map_config.dart';
import 'package:tashila_client/core/formatting/app_format.dart';
import 'package:tashila_client/core/state/app_state.dart';
import 'package:tashila_client/core/theme/app_colors.dart';
import 'package:tashila_client/core/widgets/primary_button.dart';
import 'package:tashila_client/features/map_booking/location_search_screen.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  bool _booking = false;

  void _openLocationSearch(BuildContext context, {required bool isPickup}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LocationSearchScreen(isPickup: isPickup),
      ),
    );
  }

  Widget _modernLocationRow(
    BuildContext context, {
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value.isNotEmpty ? value : 'search_address_hint'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: value.isNotEmpty
                          ? AppColors.textPrimary
                          : AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _BookingMapLayer()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 106),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 10,
                              color: Colors.green,
                            ),
                            Container(
                              width: 1.5,
                              height: 32,
                              color: Colors.grey.shade300,
                            ),
                            const Icon(
                              Icons.stop,
                              size: 10,
                              color: AppColors.brandOrange,
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              _modernLocationRow(
                                context,
                                title: 'pickup'.tr(),
                                value: state.pickup,
                                onTap: () => _openLocationSearch(
                                  context,
                                  isPickup: true,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Divider(height: 1, thickness: 0.5),
                              ),
                              _modernLocationRow(
                                context,
                                title: 'dropoff'.tr(),
                                value: state.dropoff,
                                onTap: () => _openLocationSearch(
                                  context,
                                  isPickup: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.04),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.035),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Segmented Vehicle Type Switcher
                        Container(
                          height: 130,
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.02),
                            ),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: TruckType.values.map((type) {
                              final selected = type == state.selectedTruck;
                              final label = type == TruckType.singleCabine
                                  ? 'single_cabine'.tr()
                                  : 'double_cabine'.tr();
                              final asset = type == TruckType.singleCabine
                                  ? 'assets/images/singlecabin_icon.png'
                                  : 'assets/images/doublecabin_icon.png';
                              final load = type == TruckType.singleCabine
                                  ? '700kg'
                                  : '700kg';

                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => ref
                                      .read(appStateProvider.notifier)
                                      .setTruckType(type),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: selected
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.04,
                                                ),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          asset,
                                          height: 88,
                                          // width: 88,
                                          fit: BoxFit.contain,
                                        ),
                                        const SizedBox(width: 2),
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              label,
                                              style: TextStyle(
                                                fontWeight: selected
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                                color: selected
                                                    ? AppColors.brandOrange
                                                    : AppColors.textPrimary,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              load,
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Cash payment badge & Request button side-by-side
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Container(
                                height: 52,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.bg,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.payments_outlined,
                                      color: AppColors.brandOrange,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'cash'.tr(),
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 9,
                                                ),
                                          ),
                                          Text(
                                            formatTripPrice(
                                              state.estimatedPrice,
                                            ),
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                  color: AppColors.brandOrange,
                                                  fontSize: 14,
                                                  height: 1.1,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 5,
                              child: SizedBox(
                                height: 52,
                                child: PrimaryButton(
                                  label: 'create_request'.tr(),
                                  isLoading: _booking,
                                  onPressed: state.canCreateTransportRequest
                                      ? () async {
                                          final proceed = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              backgroundColor: Colors.white,
                                              surfaceTintColor:
                                                  Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              title: Text(
                                                'warning_title'.tr(),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              content: Text(
                                                'booking_delay_charges_notice'
                                                    .tr(),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  height: 1.4,
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  style: TextButton.styleFrom(
                                                    foregroundColor:
                                                        AppColors.textSecondary,
                                                  ),
                                                  child: Text(
                                                    'cancel_button'.tr(),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  style: TextButton.styleFrom(
                                                    foregroundColor:
                                                        AppColors.brandOrange,
                                                  ),
                                                  child: Text(
                                                    'continue_button'.tr(),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (proceed != true) return;

                                          setState(() => _booking = true);
                                          var ok = false;
                                          try {
                                            ok = await ref
                                                .read(appStateProvider.notifier)
                                                .createTransportRequest();
                                          } catch (_) {}
                                          if (!context.mounted) return;
                                          setState(() => _booking = false);
                                          if (ok) {
                                            context.go('/trip');
                                          } else if (ref
                                              .read(appStateProvider)
                                              .isLoggedIn) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'create_trip_failed'.tr(),
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if ((state.pickup.isNotEmpty &&
                                !state.pickupInServiceArea) ||
                            (state.dropoff.isNotEmpty &&
                                !state.dropoffInServiceArea)) ...[
                          const SizedBox(height: 8),
                          Text(
                            'service_area_unavailable'.tr(),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingMapLayer extends ConsumerStatefulWidget {
  const _BookingMapLayer();

  @override
  ConsumerState<_BookingMapLayer> createState() => _BookingMapLayerState();
}

class _BookingMapLayerState extends ConsumerState<_BookingMapLayer> {
  static const _initialCamera = CameraPosition(
    target: LatLng(22.785, 5.523),
    zoom: 11.5,
  );

  static final Set<Factory<OneSequenceGestureRecognizer>> _gestures = {
    Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
  };

  GoogleMapController? _controller;
  bool _mapReady = false;

  Future<void> _fitCamera(
    double pickupLat,
    double pickupLng,
    double dropoffLat,
    double dropoffLng,
  ) async {
    final c = _controller;
    if (c == null) return;

    final hasPickup = pickupLat != 0.0 && pickupLng != 0.0;
    final hasDropoff = dropoffLat != 0.0 && dropoffLng != 0.0;

    if (!hasPickup && !hasDropoff) {
      await _moveToCurrentLocation();
      return;
    }

    if (hasPickup && !hasDropoff) {
      await c.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pickupLat, pickupLng), 14.5),
      );
      return;
    }

    if (!hasPickup && hasDropoff) {
      await c.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(dropoffLat, dropoffLng), 14.5),
      );
      return;
    }

    final p = LatLng(pickupLat, pickupLng);
    final d = LatLng(dropoffLat, dropoffLng);

    final latDiff = (p.latitude - d.latitude).abs();
    final lngDiff = (p.longitude - d.longitude).abs();
    if (latDiff < 1e-7 && lngDiff < 1e-7) {
      await c.animateCamera(CameraUpdate.newLatLngZoom(p, 14.5));
      return;
    }

    final south = math.min(p.latitude, d.latitude);
    final north = math.max(p.latitude, d.latitude);
    final west = math.min(p.longitude, d.longitude);
    final east = math.max(p.longitude, d.longitude);
    final latPad = math.max(0.015, (north - south) * 0.25);
    final lngPad = math.max(0.015, (east - west) * 0.25);

    final bounds = LatLngBounds(
      southwest: LatLng(south - latPad, west - lngPad),
      northeast: LatLng(north + latPad, east + lngPad),
    );
    await c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 56));
  }

  void _showLocationServiceDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'warning_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'location_disabled_body'.tr(),
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: Text(
              'cancel_button'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openLocationSettings();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.brandOrange),
            child: Text(
              'settings_button'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'warning_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'location_permission_denied'.tr(),
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: Text(
              'cancel_button'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openAppSettings();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.brandOrange),
            child: Text(
              'settings_button'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _moveToCurrentLocation() async {
    final c = _controller;
    if (c == null) return;
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _showLocationServiceDialog();
        await c.animateCamera(CameraUpdate.newCameraPosition(_initialCamera));
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        _showPermissionDialog();
        await c.animateCamera(CameraUpdate.newCameraPosition(_initialCamera));
        return;
      }
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos != null) {
        await c.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 14.5),
        );
      } else {
        await c.animateCamera(CameraUpdate.newCameraPosition(_initialCamera));
      }
    } catch (_) {
      await c.animateCamera(CameraUpdate.newCameraPosition(_initialCamera));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pins = ref.watch(
      appStateProvider.select(
        (s) => (s.pickupLat, s.pickupLng, s.dropoffLat, s.dropoffLng),
      ),
    );
    final routePoints = ref.watch(
      appStateProvider.select((s) => s.routePoints),
    );

    ref.listen(
      appStateProvider.select(
        (s) => (s.pickupLat, s.pickupLng, s.dropoffLat, s.dropoffLng),
      ),
      (previous, next) {
        if (previous == null) return;
        if (previous == next) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitCamera(next.$1, next.$2, next.$3, next.$4);
        });
      },
    );

    if (!MapConfig.canRenderGoogleMap) {
      return Container(
        color: Colors.white,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('map_disabled_message'.tr(), textAlign: TextAlign.center),
        ),
      );
    }

    final hasPickup = pins.$1 != 0.0 && pins.$2 != 0.0;
    final hasDropoff = pins.$3 != 0.0 && pins.$4 != 0.0;

    return Stack(
      children: [
        GoogleMap(
          key: const ValueKey('booking_google_map'),
          initialCameraPosition: _initialCamera,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          gestureRecognizers: _gestures,
          markers: {
            if (hasPickup)
              Marker(
                markerId: const MarkerId('pickup'),
                position: LatLng(pins.$1, pins.$2),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
                infoWindow: InfoWindow(title: 'pickup'.tr()),
              ),
            if (hasDropoff)
              Marker(
                markerId: const MarkerId('dropoff'),
                position: LatLng(pins.$3, pins.$4),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange,
                ),
                infoWindow: InfoWindow(title: 'dropoff'.tr()),
              ),
          },
          polylines: {
            if (routePoints.isNotEmpty)
              Polyline(
                polylineId: const PolylineId('booking_route'),
                points: routePoints,
                width: 4,
                color: AppColors.brandOrange,
              ),
          },
          onMapCreated: (c) {
            _controller = c;
            setState(() => _mapReady = true);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fitCamera(pins.$1, pins.$2, pins.$3, pins.$4);
            });
          },
        ),
        if (_mapReady)
          Positioned(
            right: 16,
            bottom: MediaQuery.sizeOf(context).height * 0.40 + 36,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              foregroundColor: AppColors.brandOrange,
              shape: const CircleBorder(),
              elevation: 4,
              onPressed: _moveToCurrentLocation,
              child: const Icon(Icons.gps_fixed, size: 20),
            ),
          ),
        if (!_mapReady)
          const Center(
            child: CircularProgressIndicator(color: AppColors.brandOrange),
          ),
      ],
    );
  }
}
