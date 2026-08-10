import 'dart:async';
import 'dart:math' as math;

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
import 'package:tashila_client/core/widgets/rating_sheet_host.dart';
import 'package:tashila_client/features/trip_flow/cancel_trip_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

class TripScreen extends ConsumerStatefulWidget {
  const TripScreen({super.key});

  @override
  ConsumerState<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends ConsumerState<TripScreen> {
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _syncElapsedTimer(ref.read(appStateProvider));
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }

  /// Starts / stops the 1-second ticker based on current trip stage.
  void _syncElapsedTimer(AppState state) {
    if (state.tripStage == TripStage.tripStarted) {
      if (_elapsedTimer == null || !_elapsedTimer!.isActive) {
        // Seed elapsed from startTime if available.
        if (state.tripStartTime != null) {
          _elapsedSeconds = DateTime.now()
              .difference(state.tripStartTime!)
              .inSeconds
              .clamp(0, 86400);
        }
        _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          setState(() => _elapsedSeconds++);
        });
      }
    } else {
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
    }
  }

  Future<void> _showDriverRatingSheet() async {
    if (!mounted) return;
    await showRequiredDriverRatingSheet(context);
    if (!mounted) return;
    if (ref.read(appStateProvider).tripStage == TripStage.idle) {
      context.go('/home');
    }
  }

  /*
  static bool _showDriverMarker(TripStage stage) {
    return stage != TripStage.idle &&
        stage != TripStage.searchingDriver &&
        stage != TripStage.noDriversFound;
  }
  */

  Future<void> _onCancelTripPressed(BuildContext context) async {
    final reason = await showCancelTripReasonSheet(context);
    if (!context.mounted) return;
    if (reason == null || reason.trim().isEmpty) return;
    await ref
        .read(appStateProvider.notifier)
        .cancelTripWithReason(reason.trim());
    if (!context.mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    _syncElapsedTimer(state);

    if (state.tripStage == TripStage.arrivedSummary) {
      return _buildArrivedSummaryScreen(context, state);
    }

    final pickup = LatLng(state.pickupLat, state.pickupLng);
    final dropoff = LatLng(state.dropoffLat, state.dropoffLng);
    // final driverPos = state.hasDriverLocation
    //     ? LatLng(state.driverLat!, state.driverLng!)
    //     : _driverAlongRoute(pickup, dropoff, state.tripStage);
    final mid = LatLng(
      (pickup.latitude + dropoff.latitude) / 2,
      (pickup.longitude + dropoff.longitude) / 2,
    );
    final span = math.max(
      (pickup.latitude - dropoff.latitude).abs(),
      (pickup.longitude - dropoff.longitude).abs(),
    );
    final zoom = span > 0.08 ? 11.0 : (span > 0.03 ? 12.5 : 14.0);

    // final showDriverMarker =
    //     _showDriverMarker(state.tripStage) && state.hasDriverLocation;
    final maxPanelH = (MediaQuery.sizeOf(context).height * 0.45).clamp(
      320.0,
      480.0,
    );
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
    /*
    if (showDriverMarker) {
      final driverTitle = state.driverName.isNotEmpty
          ? state.driverName
          : 'trip_driver_pending'.tr();
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: driverPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: driverTitle,
            snippet: state.hasDriverLocation
                ? 'driver_live_on_map'.tr()
                : 'trip_driver_estimated_position'.tr(),
          ),
        ),
      );
    }
    */

    return PopScope(
      canPop: true,
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
                      gestureRecognizers:
                          <foundation.Factory<OneSequenceGestureRecognizer>>{
                            foundation.Factory<OneSequenceGestureRecognizer>(
                              () => EagerGestureRecognizer(),
                            ),
                          },
                      polylines: {
                        Polyline(
                          polylineId: const PolylineId('route'),
                          points: state.routePoints.isNotEmpty
                              ? state.routePoints
                              : [pickup, mid, dropoff],
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
                          child: switch (state.tripStage) {
                            TripStage.idle => const SizedBox.shrink(),
                            TripStage.searchingDriver =>
                              _buildSearchingDriverPanel(context, state),
                            TripStage.noDriversFound =>
                              _buildNoDriversFoundPanel(context, state),
                            TripStage.driverEnRoute ||
                            TripStage.tripStarted ||
                            TripStage.awaitingPayment =>
                              _buildDriverAcceptedPanel(context, state),
                            TripStage.arrivedSummary => const SizedBox.shrink(),
                          },
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

  Widget _buildSearchingDriverPanel(BuildContext context, AppState state) {
    return Column(
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
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.brandOrange,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'searching_drivers_title'.tr(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Vertical Endpoints Display
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dot/Line indicator
              Column(
                children: [
                  const SizedBox(height: 4),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2E7D32),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(width: 2, height: 36, color: Colors.grey.shade300),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.brandOrange,
                      shape: BoxShape.rectangle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Text Fields
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'trip_summary_from_label'.tr(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    Text(
                      state.pickup,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'trip_summary_to_label'.tr(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    Text(
                      state.dropoff,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Cancel Button

        // Price & Cash Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'fixed_price'.tr(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  formatTripPrice(
                    state.estimatedPrice > 0
                        ? state.estimatedPrice
                        : kEstimatedTripPrice,
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.brandOrange,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.payments_rounded,
                    color: Colors.amber,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'cash_payment'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => _onCancelTripPressed(context),
            icon: const Icon(Icons.close_rounded, color: Colors.red, size: 18),
            label: Text(
              'cancel_order'.tr(),
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.red.shade50.withValues(alpha: 0.1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDriverAcceptedPanel(BuildContext context, AppState state) {
    final distance = tripRouteDistanceKm(
      state.pickupLat,
      state.pickupLng,
      state.dropoffLat,
      state.dropoffLng,
    );

    return Column(
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
        const SizedBox(height: 10),
        // Top Floating Driver Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.brandOrange.withValues(alpha: 0.1),
                backgroundImage: state.driverAvatarUrl.isNotEmpty
                    ? NetworkImage(state.driverAvatarUrl)
                    : null,
                child: state.driverAvatarUrl.isEmpty
                    ? const Icon(
                        Icons.person_rounded,
                        color: AppColors.brandOrange,
                        size: 28,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // Driver Name and 5 Stars colored rating
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.driverName.isNotEmpty
                          ? state.driverName
                          : 'trip_driver_pending'.tr(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (index) {
                        return const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 14,
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Section for details of vehicle
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      state.selectedTruck == TruckType.singleCabine
                          ? 'single_cabine'.tr()
                          : 'double_cabine'.tr(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandOrange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.driverVehicleModel.isNotEmpty
                        ? (state.driverVehicleColor.isNotEmpty
                            ? '${state.driverVehicleModel} (${state.driverVehicleColor})'
                            : state.driverVehicleModel)
                        : 'trip_vehicle_pending'.tr(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    state.driverPlate.isNotEmpty
                        ? state.driverPlate
                        : 'trip_plate_pending'.tr(),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Trip Stats (2 or 3 cards side-by-side)
        Row(
          children: [
            // Price Card
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade100),
                ),
                child: Column(
                  children: [
                    Text(
                      'trip_summary_price_label'.tr(),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatTripPrice(
                        state.estimatedPrice > 0
                            ? state.estimatedPrice
                            : kEstimatedTripPrice,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.brandOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Distance Card
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Text(
                      'trip_summary_distance_label'.tr(),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${distance.toStringAsFixed(1)} ${'trip_summary_km_unit'.tr()}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // // Live Elapsed Timer Card — only shown when trip is in progress
            // if (state.tripStage == TripStage.tripStarted) ...[
            //   const SizedBox(width: 8),
            //   Expanded(
            //     child: Container(
            //       padding: const EdgeInsets.symmetric(
            //         vertical: 8,
            //         horizontal: 4,
            //       ),
            //       decoration: BoxDecoration(
            //         color: const Color(0xFFE8F4FD),
            //         borderRadius: BorderRadius.circular(12),
            //         border: Border.all(color: const Color(0xFFBBDEFB)),
            //       ),
            //       child: Column(
            //         children: [
            //           Text(
            //             'trip_summary_duration_label'.tr(),
            //             style: TextStyle(
            //               fontSize: 10,
            //               color: Colors.grey.shade500,
            //               fontWeight: FontWeight.bold,
            //             ),
            //           ),
            //           const SizedBox(height: 2),
            //           Text(
            //             _formatElapsed(_elapsedSeconds),
            //             style: const TextStyle(
            //               fontSize: 13,
            //               fontWeight: FontWeight.w900,
            //               color: Color(0xFF1565C0),
            //               fontFeatures: [FontFeature.tabularFigures()],
            //             ),
            //           ),
            //         ],
            //       ),
            //     ),
            //   ),
            // ],
          ],
        ),
        const SizedBox(height: 12),
        // Action Buttons Row
        Row(
          children: [
            if (state.canCancelActiveTrip) ...[
              // Small cancel button (cross icon)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _onCancelTripPressed(context),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            // Call Action Button
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: state.driverPhone.trim().isNotEmpty
                      ? () => launchUrl(Uri.parse('tel:${state.driverPhone}'))
                      : null,
                  icon: const Icon(Icons.phone_rounded, size: 18),
                  label: Text(
                    'driver_contact'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoDriversFoundPanel(BuildContext context, AppState state) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.person_off_outlined, size: 44, color: Colors.red.shade700),
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
  }

  Widget _buildArrivedSummaryScreen(BuildContext context, AppState state) {
    final distance = tripRouteDistanceKm(
      state.pickupLat,
      state.pickupLng,
      state.dropoffLat,
      state.dropoffLng,
    );
    final durationText = _formatDuration(
      state.tripStartTime,
      state.tripEndTime,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(appStateProvider.notifier).completeRatingSession();
        context.go('/home');
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          // leading: IconButton(
          //   icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          //   onPressed: () {
          //     ref.read(appStateProvider.notifier).completeRatingSession();
          //     context.go('/home');
          //   },
          // ),
          title: Text(
            'trip_summary_title'.tr(),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                // Success Checkmark
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 48,
                      color: AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'trip_completed_successfully'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'thank_you_trust'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),

                // Price Badge Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.brandOrange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.brandOrange.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'total_value'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.payments_rounded,
                                  color: Colors.amber,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'cash_payment'.tr(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        formatTripPrice(
                          state.estimatedPrice > 0
                              ? state.estimatedPrice
                              : kEstimatedTripPrice,
                        ),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.brandOrange,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Side-by-side stats cards
                Row(
                  children: [
                    // Distance Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.pin_drop_rounded,
                              color: AppColors.brandOrange,
                              size: 20,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'trip_summary_distance_label'.tr(),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${distance.toStringAsFixed(1)} ${'trip_summary_km_unit'.tr()}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Duration Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              color: AppColors.brandOrange,
                              size: 20,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'trip_summary_duration_label'.tr(),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              durationText,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Mini Map Card
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: !MapConfig.canRenderGoogleMap
                      ? const Center(
                          child: Icon(
                            Icons.map_rounded,
                            size: 44,
                            color: Colors.grey,
                          ),
                        )
                      : GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                              (state.pickupLat + state.dropoffLat) / 2,
                              (state.pickupLng + state.dropoffLng) / 2,
                            ),
                            zoom: 12.5,
                          ),
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                          scrollGesturesEnabled: false,
                          zoomGesturesEnabled: false,
                          rotateGesturesEnabled: false,
                          tiltGesturesEnabled: false,
                          markers: {
                            Marker(
                              markerId: const MarkerId('pickup'),
                              position: LatLng(
                                state.pickupLat,
                                state.pickupLng,
                              ),
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueGreen,
                              ),
                            ),
                            Marker(
                              markerId: const MarkerId('dropoff'),
                              position: LatLng(
                                state.dropoffLat,
                                state.dropoffLng,
                              ),
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueOrange,
                              ),
                            ),
                          },
                          polylines: {
                            Polyline(
                              polylineId: const PolylineId('route'),
                              points: state.routePoints.isNotEmpty
                                  ? state.routePoints
                                  : [
                                      LatLng(state.pickupLat, state.pickupLng),
                                      LatLng(
                                        (state.pickupLat + state.dropoffLat) /
                                            2,
                                        (state.pickupLng + state.dropoffLng) /
                                            2,
                                      ),
                                      LatLng(
                                        state.dropoffLat,
                                        state.dropoffLng,
                                      ),
                                    ],
                              width: 3,
                              color: AppColors.brandOrange,
                            ),
                          },
                        ),
                ),
                const SizedBox(height: 24),

                // Rate Driver Button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _showDriverRatingSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'trip_rate_driver'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Formats elapsed seconds as HH:MM:SS (or MM:SS when under 1 hour) for the
  /// live trip timer displayed during [TripStage.tripStarted].
  String _formatElapsed(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /*
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
  */
}

String _formatDuration(DateTime? start, DateTime? end) {
  if (start == null || end == null) return '—';
  final d = end.difference(start);
  final hours = d.inHours.toString().padLeft(2, '0');
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return ltrNumber('$hours:$minutes:$seconds');
}
