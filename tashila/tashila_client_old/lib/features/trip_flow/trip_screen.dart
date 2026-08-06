import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tashila_client/core/config/map_config.dart';
import 'package:tashila_client/core/formatting/app_format.dart';
import 'package:tashila_client/core/state/app_state.dart';
import 'package:tashila_client/core/theme/app_colors.dart';
import 'package:tashila_client/core/widgets/trip_stage_indicator.dart';
import 'package:tashila_client/core/widgets/rating_sheet_host.dart';
import 'package:tashila_client/features/trip_flow/cancel_trip_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

class TripScreen extends ConsumerStatefulWidget {
  const TripScreen({super.key});

  @override
  ConsumerState<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends ConsumerState<TripScreen> {
  Future<void> _showDriverRatingSheet() async {
    if (!mounted) return;
    await showRequiredDriverRatingSheet(context);
    if (!mounted) return;
    if (ref.read(appStateProvider).tripStage == TripStage.idle) {
      context.go('/home');
    }
  }

  static bool _showDriverMarker(TripStage stage) {
    return stage != TripStage.idle &&
        stage != TripStage.searchingDriver &&
        stage != TripStage.noDriversFound;
  }

  static bool _canCancelTrip(AppState state) => state.canCancelActiveTrip;

  Future<void> _onCancelTripPressed(BuildContext context) async {
    final reason = await showCancelTripReasonSheet(context);
    if (!context.mounted) return;
    if (reason == null || reason.trim().isEmpty) return;
    await ref.read(appStateProvider.notifier).cancelTripWithReason(reason.trim());
    if (!context.mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppState>(appStateProvider, (previous, next) {
      if (previous?.tripStage != TripStage.arrivedSummary &&
          next.tripStage == TripStage.arrivedSummary) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showDriverRatingSheet();
        });
      }
    });

    final state = ref.watch(appStateProvider);
    final pickup = LatLng(state.pickupLat, state.pickupLng);
    final dropoff = LatLng(state.dropoffLat, state.dropoffLng);
    final driverPos = state.hasDriverLocation
        ? LatLng(state.driverLat!, state.driverLng!)
        : _driverAlongRoute(pickup, dropoff, state.tripStage);
    final mid = LatLng(
      (pickup.latitude + dropoff.latitude) / 2,
      (pickup.longitude + dropoff.longitude) / 2,
    );
    final span = math.max(
      (pickup.latitude - dropoff.latitude).abs(),
      (pickup.longitude - dropoff.longitude).abs(),
    );
    final zoom = span > 0.08 ? 11.0 : (span > 0.03 ? 12.5 : 14.0);

    final showDriverMarker = _showDriverMarker(state.tripStage);
    final canCancel = _canCancelTrip(state);
    final maxPanelH = (MediaQuery.sizeOf(context).height * 0.36).clamp(240.0, 400.0);
    final panelW = MediaQuery.sizeOf(context).width - 28;

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        position: pickup,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('dropoff'),
        position: dropoff,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
    };
    if (showDriverMarker) {
      final driverTitle = state.driverName.isNotEmpty
          ? state.driverName
          : 'trip_driver_pending'.tr();
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: driverPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: driverTitle,
            snippet: state.hasDriverLocation
                ? 'driver_live_on_map'.tr()
                : 'trip_driver_estimated_position'.tr(),
          ),
        ),
      );
    }

    return PopScope(
      canPop: state.tripStage != TripStage.arrivedSummary,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (state.tripStage == TripStage.arrivedSummary) {
          _showDriverRatingSheet();
        }
      },
      child: Scaffold(
      extendBody: true,
      appBar: AppBar(title: Text('trip_flow'.tr())),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: !MapConfig.canRenderGoogleMap
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'map_disabled_message'.tr(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: mid,
                      zoom: zoom,
                    ),
                    gestureRecognizers: <foundation.Factory<OneSequenceGestureRecognizer>>{
                      foundation.Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                    polylines: {
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: [pickup, mid, dropoff],
                        width: 4,
                        color: AppColors.brandOrange,
                      ),
                    },
                    markers: markers,
                  ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              color: Colors.white,
              elevation: 16,
              shadowColor: Colors.black38,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxPanelH),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: panelW,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.textSecondary.withValues(alpha: 0.28),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (state.tripStage != TripStage.noDriversFound) ...[
                              TripStageIndicator(stage: state.tripStage, compact: true),
                              const SizedBox(height: 6),
                            ],
                            if (state.tripStage != TripStage.idle &&
                                state.tripStage != TripStage.searchingDriver &&
                                state.tripStage != TripStage.noDriversFound)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: _TripDriverInfoCard(
                                  stage: state.tripStage,
                                  truckType: state.selectedTruck,
                                  driverName: state.driverName,
                                  driverPhone: state.driverPhone,
                                  driverPlate: state.driverPlate,
                                  driverVehicleColor: state.driverVehicleColor,
                                  driverVehicleModel: state.driverVehicleModel,
                                ),
                              ),
                            _TripStageBody(
                              stage: state.tripStage,
                              state: state,
                              pickup: pickup,
                              dropoff: dropoff,
                              onOpenRating: _showDriverRatingSheet,
                            ),
                            if (canCancel) ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFC62828),
                                  side: const BorderSide(color: Color(0xFFE57373)),
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => _onCancelTripPressed(context),
                                icon: const Icon(Icons.close_rounded, size: 18),
                                label: Text(
                                  'cancel_trip'.tr(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  static LatLng _driverAlongRoute(LatLng a, LatLng b, TripStage stage) {
    final t = switch (stage) {
      TripStage.searchingDriver => 0.08,
      TripStage.noDriversFound => 0.08,
      TripStage.driverEnRoute => 0.28,
      TripStage.tripStarted => 0.62,
      TripStage.awaitingPayment => 0.88,
      TripStage.arrivedSummary => 0.96,
      TripStage.idle => 0.45,
    };
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }
}

Future<void> _openMapsSearch(LatLng location) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}',
  );
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Pickup / drop-off in one row; opens Maps on tap.
class _ClientRouteEndpointsRow extends StatelessWidget {
  const _ClientRouteEndpointsRow({
    required this.pickupAddress,
    required this.dropAddress,
    required this.pickup,
    required this.dropoff,
  });

  final String pickupAddress;
  final String dropAddress;
  final LatLng pickup;
  final LatLng dropoff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const radius = 12.0;
    const pad = EdgeInsets.symmetric(horizontal: 8, vertical: 8);

    Widget buildCell({
      required Color dot,
      required String label,
      required String address,
      required VoidCallback onTap,
    }) {
      return Material(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: pad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 13,
                      color: AppColors.brandOrange.withValues(alpha: 0.85),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final rtl = Directionality.of(context) == ui.TextDirection.rtl;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: buildCell(
            dot: const Color(0xFF2E7D32),
            label: 'trip_summary_from_label'.tr(),
            address: pickupAddress,
            onTap: () => _openMapsSearch(pickup),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Icon(
              rtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
              size: 16,
              color: AppColors.textSecondary.withValues(alpha: 0.45),
            ),
          ),
        ),
        Expanded(
          child: buildCell(
            dot: AppColors.brandOrange,
            label: 'trip_summary_to_label'.tr(),
            address: dropAddress,
            onTap: () => _openMapsSearch(dropoff),
          ),
        ),
      ],
    );
  }
}

class _TripStageBody extends ConsumerWidget {
  const _TripStageBody({
    required this.stage,
    required this.state,
    required this.pickup,
    required this.dropoff,
    required this.onOpenRating,
  });

  final TripStage stage;
  final AppState state;
  final LatLng pickup;
  final LatLng dropoff;
  final Future<void> Function() onOpenRating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    switch (stage) {
      case TripStage.idle:
        return Center(child: Text('trip_idle'.tr()));
      case TripStage.searchingDriver:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.radar, size: 24, color: AppColors.brandOrange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'searching_drivers_title'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'searching_drivers_subtitle'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'searching_dispatch_hint'.tr(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: const LinearProgressIndicator(
                minHeight: 6,
                backgroundColor: Color(0xFFFFE4D0),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.brandOrange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'searching_contact_status'.tr(),
                    style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        );
      case TripStage.noDriversFound:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 44,
              color: Colors.red.shade700,
            ),
            const SizedBox(height: 12),
            Text(
              'no_drivers_found_title'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.red.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'no_drivers_found_message'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                ref.read(appStateProvider.notifier).dismissNoDriversFound();
                context.go('/home');
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text('no_drivers_found_try_again'.tr()),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandOrange,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        );
      case TripStage.driverEnRoute:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'trip_driver_status_en_route'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (state.hasDriverLocation) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.my_location_rounded,
                    size: 16,
                    color: AppColors.brandOrange,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'driver_live_on_map'.tr(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.brandOrange,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            _ClientRouteEndpointsRow(
              pickupAddress: state.pickup,
              dropAddress: state.dropoff,
              pickup: pickup,
              dropoff: dropoff,
            ),
          ],
        );
      case TripStage.tripStarted:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.hasDriverLocation) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.my_location_rounded,
                    size: 16,
                    color: AppColors.brandOrange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'driver_live_on_map'.tr(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.brandOrange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            _ClientRouteEndpointsRow(
              pickupAddress: state.pickup,
              dropAddress: state.dropoff,
              pickup: pickup,
              dropoff: dropoff,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.local_shipping_outlined, color: AppColors.brandOrange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'trip_started_title'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'trip_started_auto_complete_hint'.tr(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case TripStage.awaitingPayment:
        final priceStr = formatTripPrice(
          state.estimatedPrice > 0 ? state.estimatedPrice : kEstimatedTripPrice,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.payments_outlined, color: AppColors.brandOrange, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'trip_awaiting_payment_title'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'trip_awaiting_payment_message'.tr(namedArgs: {'amount': priceStr}),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'trip_awaiting_payment_hint'.tr(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case TripStage.arrivedSummary:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TripConclusionCard(state: state, compact: true),
            const SizedBox(height: 8),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AppColors.brandOrange,
              ),
              onPressed: () => onOpenRating(),
              icon: const Icon(Icons.star_rounded, size: 20),
              label: Text(
                'trip_rate_driver'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ],
        );
    }
  }
}

class _TripDriverInfoCard extends StatelessWidget {
  const _TripDriverInfoCard({
    required this.stage,
    required this.truckType,
    required this.driverName,
    required this.driverPhone,
    required this.driverPlate,
    required this.driverVehicleColor,
    required this.driverVehicleModel,
  });

  final TripStage stage;
  final TruckType truckType;
  final String driverName;
  final String driverPhone;
  final String driverPlate;
  final String driverVehicleColor;
  final String driverVehicleModel;

  String _vehicleLine(String labelKey, String value, String pendingKey) {
    final text = value.trim().isNotEmpty ? value.trim() : pendingKey.tr();
    return '${labelKey.tr()}: $text';
  }

  String? get _statusHint {
    return switch (stage) {
      TripStage.driverEnRoute => 'trip_driver_status_en_route'.tr(),
      TripStage.awaitingPayment => 'trip_awaiting_payment_title'.tr(),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeLabel =
        truckType == TruckType.singleCabine ? 'single_cabine'.tr() : 'double_cabine'.tr();
    final phoneText = driverPhone.isNotEmpty
        ? driverPhone
        : 'trip_driver_phone_pending'.tr();
    final statusHint = _statusHint;
    final vehicleLines = [
      _vehicleLine('trip_driver_plate_label', driverPlate, 'trip_plate_pending'),
      _vehicleLine('vehicle_line_model', driverVehicleModel, 'trip_vehicle_pending'),
      _vehicleLine('vehicle_line_color', driverVehicleColor, 'trip_vehicle_pending'),
      '${'vehicle_line_type'.tr()}: $typeLabel',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.brandOrange.withValues(alpha: 0.2),
            AppColors.brandOrange.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.brandOrange.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.brandOrange.withValues(alpha: 0.28),
            child: Icon(Icons.person_rounded, color: AppColors.brandOrange, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  driverName.isNotEmpty
                      ? driverName
                      : 'trip_driver_pending'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${'trip_driver_phone_label'.tr()}: $phoneText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                ...vehicleLines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ),
                if (statusHint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    statusHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.brandOrange,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            padding: EdgeInsets.zero,
            tooltip: 'driver_contact'.tr(),
            icon: Icon(Icons.call_rounded, color: AppColors.brandOrange, size: 22),
            onPressed: driverPhone.isEmpty
                ? null
                : () => launchUrl(Uri.parse('tel:$driverPhone')),
          ),
        ],
      ),
    );
  }
}

class _TripConclusionCard extends StatelessWidget {
  const _TripConclusionCard({
    required this.state,
    this.compact = false,
  });

  final AppState state;
  final bool compact;

  static String _formatDuration(DateTime? start, DateTime? end) {
    if (start == null || end == null) return '—';
    final d = end.difference(start);
    if (d.inHours >= 1) {
      return ltrNumber(
        '${d.inHours} ${'trip_unit_hours'.tr()} ${d.inMinutes.remainder(60)} ${'trip_unit_minutes'.tr()}',
      );
    }
    if (d.inMinutes >= 1) {
      return ltrNumber('${d.inMinutes} ${'trip_unit_minutes'.tr()}');
    }
    return ltrNumber('${d.inSeconds} ${'trip_unit_seconds'.tr()}');
  }

  static String _formatPrice(AppState state) {
    final amount = state.estimatedPrice > 0 ? state.estimatedPrice : kEstimatedTripPrice;
    return formatTripPrice(amount);
  }

  static String _formatDistanceKm(double km) {
    return ltrNumber('${km.toStringAsFixed(1)} ${'trip_summary_km_unit'.tr()}');
  }

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact(context);
    final theme = Theme.of(context);
    final km = tripRouteDistanceKm(
      state.pickupLat,
      state.pickupLng,
      state.dropoffLat,
      state.dropoffLng,
    );
    final priceStr = _formatPrice(state);

    return Card(
      color: AppColors.brandOrange.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.brandOrange.withValues(alpha: 0.5), width: 1.5),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route_rounded, color: AppColors.brandOrange, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'trip_summary_title'.tr(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _summaryRow(
              context,
              'trip_summary_duration_label'.tr(),
              _formatDuration(state.tripStartTime, state.tripEndTime),
            ),
            _summaryRow(context, 'trip_summary_from_label'.tr(), state.pickup),
            _summaryRow(context, 'trip_summary_to_label'.tr(), state.dropoff),
            _summaryRow(
              context,
              'trip_summary_distance_label'.tr(),
              _formatDistanceKm(km),
            ),
            _summaryRow(
              context,
              'trip_summary_price_label'.tr(),
              priceStr,
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final theme = Theme.of(context);
    final km = tripRouteDistanceKm(
      state.pickupLat,
      state.pickupLng,
      state.dropoffLat,
      state.dropoffLng,
    );
    final priceStr = _formatPrice(state);
    final rtl = Directionality.of(context) == ui.TextDirection.rtl;

    return Card(
      color: AppColors.brandOrange.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.brandOrange.withValues(alpha: 0.5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.route_rounded, color: AppColors.brandOrange, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'trip_summary_title'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  priceStr,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.brandOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _compactKV(
                    context,
                    'trip_summary_duration_label'.tr(),
                    _formatDuration(state.tripStartTime, state.tripEndTime),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 1,
                  height: 40,
                  color: AppColors.textSecondary.withValues(alpha: 0.15),
                ),
                Expanded(
                  child: _compactKV(
                    context,
                    'trip_summary_distance_label'.tr(),
                    _formatDistanceKm(km),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Divider(height: 1, color: AppColors.brandOrange.withValues(alpha: 0.22)),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _compactAddr(
                    context,
                    'trip_summary_from_label'.tr(),
                    state.pickup,
                    const Color(0xFF2E7D32),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10, left: 4, right: 4),
                  child: Icon(
                    rtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                    size: 16,
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                  ),
                ),
                Expanded(
                  child: _compactAddr(
                    context,
                    'trip_summary_to_label'.tr(),
                    state.dropoff,
                    AppColors.brandOrange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactKV(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _compactAddr(
    BuildContext context,
    String label,
    String value,
    Color dot,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 11.5,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(
    BuildContext context,
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                    color: emphasize ? AppColors.brandOrange : AppColors.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

