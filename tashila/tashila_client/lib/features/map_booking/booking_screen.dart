import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
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
import 'package:tashila_client/core/widgets/truck_type_card.dart';
import 'package:tashila_client/features/map_booking/location_search_screen.dart';

class BookingScreen extends ConsumerWidget {
  const BookingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: _BookingMapLayer(),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Column(
                        children: [
                          _locationRow(
                            context,
                            icon: Icons.radio_button_checked,
                            label: 'pickup'.tr(),
                            value: state.pickup,
                            onTap: () => _openLocationSearch(context, isPickup: true),
                          ),
                          const Divider(height: 6),
                          _locationRow(
                            context,
                            icon: Icons.trip_origin,
                            label: 'dropoff'.tr(),
                            value: state.dropoff,
                            onTap: () => _openLocationSearch(context, isPickup: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.36,
                    ),
                    child: SingleChildScrollView(
                      child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 12,
                          offset: Offset(0, -1),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('truck_type'.tr(), style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: TruckType.values.map((type) {
                            final selected = type == state.selectedTruck;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: TruckTypeCard(
                                  type: type,
                                  selected: selected,
                                  compact: true,
                                  onTap: () =>
                                      ref.read(appStateProvider.notifier).setTruckType(type),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('estimated_price'.tr()),
                            Text(
                              formatTripPrice(state.estimatedPrice),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: AppColors.brandOrange.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'booking_delay_charges_notice'.tr(),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.35,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (!state.canCreateTransportRequest)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'service_area_unavailable'.tr(),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.red.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        PrimaryButton(
                          label: 'create_request'.tr(),
                          onPressed: state.canCreateTransportRequest
                              ? () async {
                                  final ok = await ref
                                      .read(appStateProvider.notifier)
                                      .createTransportRequest();
                                  if (!context.mounted) return;
                                  if (ok) {
                                    context.go('/trip');
                                  } else if (ref.read(appStateProvider).isLoggedIn) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('create_trip_failed'.tr()),
                                      ),
                                    );
                                  }
                                }
                              : null,
                          icon: Icons.local_shipping,
                        ),
                      ],
                    ),
                  ),
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

void _openLocationSearch(BuildContext context, {required bool isPickup}) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => LocationSearchScreen(isPickup: isPickup),
    ),
  );
}

Widget _locationRow(
  BuildContext context, {
  required IconData icon,
  required String label,
  required String value,
  required VoidCallback onTap,
}) {
  return ListTile(
    onTap: onTap,
    dense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    leading: Icon(icon, size: 14, color: AppColors.brandOrange),
    title: Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    subtitle: Text(label, style: const TextStyle(fontSize: 12)),
    trailing: const Icon(Icons.edit_location_alt_outlined, size: 18),
  );
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

    final p = LatLng(pickupLat, pickupLng);
    final d = LatLng(dropoffLat, dropoffLng);

    final latDiff = (p.latitude - d.latitude).abs();
    final lngDiff = (p.longitude - d.longitude).abs();
    if (latDiff < 1e-7 && lngDiff < 1e-7) {
      await c.animateCamera(CameraUpdate.newLatLngZoom(p, 14));
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

  @override
  Widget build(BuildContext context) {
    final pins = ref.watch(
      appStateProvider.select(
        (s) => (s.pickupLat, s.pickupLng, s.dropoffLat, s.dropoffLng),
      ),
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
          child: Text(
            'map_disabled_message'.tr(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final pickupMarker = LatLng(pins.$1, pins.$2);
    final dropoffMarker = LatLng(pins.$3, pins.$4);

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
            Marker(
              markerId: const MarkerId('pickup'),
              position: pickupMarker,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: InfoWindow(title: 'pickup'.tr()),
            ),
            Marker(
              markerId: const MarkerId('dropoff'),
              position: dropoffMarker,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
              infoWindow: InfoWindow(title: 'dropoff'.tr()),
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
        if (!_mapReady)
          const Center(child: CircularProgressIndicator(color: AppColors.brandOrange)),
      ],
    );
  }
}
