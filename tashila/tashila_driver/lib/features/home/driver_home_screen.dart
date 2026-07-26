import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/map_config.dart';
import '../../core/data/neighborhoods.dart';
import '../../core/formatting/app_format.dart';
import '../../core/models/models.dart';
import '../../core/state/driver_app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/rating_sheet_host.dart';
import '../../core/widgets/trip_stage_indicator.dart';
import 'trip_requests_deck.dart';
import 'waiting_for_offer_card.dart';

String _estimatedDurationValue(int? minutes) {
  if (minutes == null || minutes <= 0) return '';
  return '${westernDigits('$minutes')} ${'trip_unit_minutes'.tr()}';
}

Future<void> _openClientRatingBottomSheet(BuildContext context) async {
  await showRequiredClientRatingSheet(context);
}

class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverAppStateProvider);
    final notifier = ref.read(driverAppStateProvider.notifier);
    final isIdlePhase =
        state.tripStatus == TripStatus.idle || state.currentRequest == null;
    final activeRequest = state.currentRequest;
    final showWaitingForOffer =
        isIdlePhase &&
        state.incomingOffers.isEmpty &&
        state.availability == AvailabilityStatus.online;
    final showOffersDeck =
        isIdlePhase &&
        state.availability == AvailabilityStatus.online &&
        state.incomingOffers.isNotEmpty;
    final documentsApproved = state.profile?.documentsApproved ?? false;

    return PopScope(
      canPop: state.tripStatus != TripStatus.awaitingClientRating,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (state.tripStatus == TripStatus.awaitingClientRating) {
          _openClientRatingBottomSheet(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _MapLayer(),
            // ── TOP HUD ──────────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand header bar & City Selector
                      _GlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            // Logo pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.brandOrange,
                                    Color(0xFFFF9E80),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.local_shipping_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'app_title'.tr(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // City location selector
                            Expanded(
                              child: _DriverCityPill(
                                location: state.driverLocation,
                                onTap: () =>
                                    _showCitySelectionSheet(context, ref),
                              ),
                            ),
                            // Today's earnings mini badge
                            if (state.tripHistory.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brandOrange.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.brandOrange.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.account_balance_wallet_outlined,
                                      size: 13,
                                      color: AppColors.brandOrange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      dzdCurrency().format(
                                        _todayEarnings(state.tripHistory),
                                      ),
                                      style: const TextStyle(
                                        color: AppColors.brandOrange,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            if (isIdlePhase &&
                                state.availability ==
                                    AvailabilityStatus.online) ...[
                              const SizedBox(width: 4),
                              _MapIconButton(
                                icon: Icons.refresh_rounded,
                                tooltip: 'refresh_requests'.tr(),
                                onTap: () => notifier.refreshNearbyRequests(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isIdlePhase) ...[
                        const SizedBox(height: 8),
                        // Availability container (Full width card, 0 overflow)
                        _AvailabilityToggle(
                          isOnline:
                              state.availability == AvailabilityStatus.online,
                          documentsApproved: documentsApproved,
                          onChanged: (on) {
                            if (!documentsApproved) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  behavior: SnackBarBehavior.floating,
                                  content: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade900.withValues(
                                        alpha: 0.95,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.orange.shade400,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'documents_not_approved_online'
                                                .tr(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                              return;
                            }
                            notifier.setAvailability(
                              on
                                  ? AvailabilityStatus.online
                                  : AvailabilityStatus.offline,
                            );
                          },
                        ),
                        if (showWaitingForOffer) ...[
                          const SizedBox(height: 8),
                          const WaitingForOfferCard(),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (!isIdlePhase)
              Positioned(
                left: 14,
                right: 14,
                bottom: 104,
                child: _GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top orange gradient accent bar
                      Container(
                        height: 4,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.brandOrange, Color(0xFFFF9E80)],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TripStageIndicator(
                              status: state.tripStatus,
                              compact: true,
                            ),
                            const SizedBox(height: 10),
                            if (activeRequest != null)
                              _ActiveTripPanel(
                                request: activeRequest,
                                state: state,
                                notifier: notifier,
                                compact: true,
                              ),
                            if (state.error != null) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
                                ),
                                child: Text(
                                  state.error!,
                                  style: TextStyle(
                                    color: Colors.red.shade800,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
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
            if (showOffersDeck)
              Positioned(
                left: 14,
                right: 14,
                bottom: 104,
                child: TripRequestsDeck(
                  offers: state.incomingOffers,
                  notifier: notifier,
                  countdownTick: state.offerCountdownTick,
                  errorText: state.error,
                  isBusy: state.isBusy,
                  vehiclePlate: state.profile?.vehiclePlate ?? '',
                  vehicleColor: state.profile?.vehicleColor ?? '',
                  vehicleModel: state.profile?.vehicleModel ?? '',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── helper ────────────────────────────────────────────────────────────────

double _todayEarnings(List<TripRecord> trips) {
  final now = DateTime.now();
  return trips
      .where(
        (t) =>
            t.completedAt.year == now.year &&
            t.completedAt.month == now.month &&
            t.completedAt.day == now.day,
      )
      .fold(0.0, (sum, t) => sum + t.fare);
}

// ─── _GlassCard ────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── _MapIconButton ─────────────────────────────────────────────────────────

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip = '',
  });
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.brandOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.brandOrange.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(icon, size: 20, color: AppColors.brandOrange),
          ),
        ),
      ),
    );
  }
}

// ─── _AvailabilityToggle ─────────────────────────────────────────────────────

class _AvailabilityToggle extends StatefulWidget {
  const _AvailabilityToggle({
    required this.isOnline,
    required this.documentsApproved,
    required this.onChanged,
  });
  final bool isOnline;
  final bool documentsApproved;
  final ValueChanged<bool>? onChanged;

  @override
  State<_AvailabilityToggle> createState() => _AvailabilityToggleState();
}

class _AvailabilityToggleState extends State<_AvailabilityToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = Tween<double>(
      begin: 1,
      end: 1.8,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
    if (widget.isOnline) _pulse.repeat(reverse: false);
  }

  @override
  void didUpdateWidget(_AvailabilityToggle old) {
    super.didUpdateWidget(old);
    if (widget.isOnline && !_pulse.isAnimating) {
      _pulse.repeat(reverse: false);
    } else if (!widget.isOnline && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.reset();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = widget.isOnline;
    final approved = widget.documentsApproved;
    final activeColor = AppColors.success;
    final offlineColor = AppColors.textSecondary;
    final dotColor = isOnline ? activeColor : offlineColor;

    final statusLabel = !approved
        ? 'offline'.tr()
        : isOnline
        ? 'online'.tr()
        : 'offline'.tr();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onChanged == null
            ? null
            : () => widget.onChanged!(!isOnline),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: isOnline && approved
                ? AppColors.success.withValues(alpha: 0.12)
                : (approved
                      ? Colors.white.withValues(alpha: 0.88)
                      : Colors.orange.shade50.withValues(alpha: 0.9)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOnline && approved
                  ? AppColors.success.withValues(alpha: 0.5)
                  : (approved
                        ? Colors.white.withValues(alpha: 0.8)
                        : Colors.orange.shade300),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isOnline && approved
                    ? AppColors.success.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Animated pulsing radar dot
              SizedBox(
                width: 24,
                height: 24,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isOnline && approved)
                      AnimatedBuilder(
                        animation: _scale,
                        builder: (_, __) => Transform.scale(
                          scale: _scale.value,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: activeColor.withValues(
                                alpha: (1 - _pulse.value) * 0.4,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: approved ? dotColor : Colors.orange.shade700,
                        shape: BoxShape.circle,
                        boxShadow: isOnline && approved
                            ? [
                                BoxShadow(
                                  color: activeColor.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'availability_label'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      statusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: !approved
                            ? Colors.orange.shade800
                            : isOnline
                            ? activeColor
                            : offlineColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Modern State Container Pill Badge
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  gradient: isOnline && approved
                      ? const LinearGradient(
                          colors: [AppColors.success, Color(0xFF66BB6A)],
                        )
                      : (approved
                            ? LinearGradient(
                                colors: [
                                  Colors.grey.shade400,
                                  Colors.grey.shade500,
                                ],
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.orange.shade600,
                                  Colors.orange.shade800,
                                ],
                              )),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    if (isOnline && approved)
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      !approved
                          ? Icons.hourglass_top_rounded
                          : isOnline
                          ? Icons.power_settings_new_rounded
                          : Icons.power_off_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      !approved
                          ? 'PENDING'.tr()
                          : (isOnline ? 'online'.tr() : 'offline'.tr()),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapLayer extends ConsumerStatefulWidget {
  const _MapLayer();

  @override
  ConsumerState<_MapLayer> createState() => _MapLayerState();
}

class _MapLayerState extends ConsumerState<_MapLayer> {
  GoogleMapController? _controller;
  LatLng? _lastCameraTarget;
  bool _mapReady = false;

  static const _mapZoom = 14.0;

  static final Set<foundation.Factory<OneSequenceGestureRecognizer>> _gestures =
      {
        foundation.Factory<OneSequenceGestureRecognizer>(
          () => EagerGestureRecognizer(),
        ),
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(driverAppStateProvider.notifier)
          .refreshDriverLocation(
            sendToServer:
                ref.read(driverAppStateProvider).availability ==
                AvailabilityStatus.online,
          );
    });
  }

  Future<void> _moveCameraTo(LatLng target) async {
    if (_lastCameraTarget == target) return;
    _lastCameraTarget = target;
    final controller = _controller;
    if (controller == null || !_mapReady) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(target, _mapZoom),
    );
  }

  LatLng _cameraTarget(DriverAppState state) {
    if (state.driverLocation case final location?) return location;
    if (state.incomingOffers.isNotEmpty) {
      return state.activeOffer!.request.pickupLatLng;
    }
    return const LatLng(22.785, 5.523);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverAppStateProvider);

    ref.listen<LatLng?>(
      driverAppStateProvider.select((s) => s.driverLocation),
      (previous, next) {
        if (next == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _moveCameraTo(next);
        });
      },
    );

    if (!MapConfig.canRenderGoogleMap) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('map_disabled_message'.tr(), textAlign: TextAlign.center),
        ),
      );
    }

    final markers = <Marker>{};
    for (final offer in state.incomingOffers) {
      final request = offer.request;
      markers.add(
        Marker(
          markerId: MarkerId(request.id),
          position: request.pickupLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: request.clientName,
            snippet: request.pickup,
          ),
        ),
      );
      markers.add(
        Marker(
          markerId: MarkerId('${request.id}_drop'),
          position: request.dropOffLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(title: request.dropOff),
        ),
      );
    }
    if (state.driverLocation case final location?) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: location,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }

    final target = _cameraTarget(state);
    final routeRequest = state.currentRequest;
    final polylines = <Polyline>{};
    if (routeRequest != null) {
      final mid = LatLng(
        (routeRequest.pickupLatLng.latitude +
                routeRequest.dropOffLatLng.latitude) /
            2,
        (routeRequest.pickupLatLng.longitude +
                routeRequest.dropOffLatLng.longitude) /
            2,
      );
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [routeRequest.pickupLatLng, mid, routeRequest.dropOffLatLng],
          width: 4,
          color: AppColors.brandOrange,
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: target, zoom: _mapZoom),
      gestureRecognizers: _gestures,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      markers: markers,
      polylines: polylines,
      onMapCreated: (controller) {
        _controller = controller;
        _mapReady = true;
        final current = ref.read(driverAppStateProvider).driverLocation;
        if (current != null) {
          _moveCameraTo(current);
        }
      },
    );
  }
}

/// Two tappable columns (pickup / drop-off) in one row — compact map affordance.
class _DriverRouteEndpointsRow extends StatelessWidget {
  const _DriverRouteEndpointsRow({
    required this.pickup,
    required this.dropOff,
    required this.onPickupTap,
    required this.onDropoffTap,
    this.compact = true,
  });

  final String pickup;
  final String dropOff;
  final VoidCallback onPickupTap;
  final VoidCallback onDropoffTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = compact ? 12.0 : 14.0;
    final pad = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
        : const EdgeInsets.all(10);

    Widget cell({
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
                      width: compact ? 6 : 7,
                      height: compact ? 6 : 7,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                      ),
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
                          fontSize: compact ? 10 : 11,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: compact ? 13 : 15,
                      color: AppColors.brandOrange.withValues(alpha: 0.85),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 4 : 6),
                Text(
                  address,
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    fontSize: compact ? 11.5 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: cell(
            dot: const Color(0xFF2E7D32),
            label: 'trip_summary_from_label'.tr(),
            address: pickup,
            onTap: onPickupTap,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 6),
          child: Padding(
            padding: EdgeInsets.only(top: compact ? 18 : 22),
            child: Icon(
              Directionality.of(context) == ui.TextDirection.rtl
                  ? Icons.arrow_back_rounded
                  : Icons.arrow_forward_rounded,
              size: compact ? 16 : 18,
              color: AppColors.textSecondary.withValues(alpha: 0.45),
            ),
          ),
        ),
        Expanded(
          child: cell(
            dot: AppColors.brandOrange,
            label: 'trip_summary_to_label'.tr(),
            address: dropOff,
            onTap: onDropoffTap,
          ),
        ),
      ],
    );
  }
}

class _ActiveTripPanel extends StatelessWidget {
  const _ActiveTripPanel({
    required this.request,
    required this.state,
    required this.notifier,
    this.compact = false,
  });

  final TripRequest request;
  final DriverAppState state;
  final DriverAppNotifier notifier;
  final bool compact;

  static ButtonStyle _denseFilled(BuildContext context) {
    return FilledButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latestTrip = state.tripHistory.isNotEmpty
        ? state.tripHistory.first
        : null;
    final gap = compact ? 6.0 : 12.0;
    final gapSm = compact ? 4.0 : 8.0;

    final TripRecord? summaryRecord = switch (state.tripStatus) {
      TripStatus.awaitingClientRating => latestTrip,
      TripStatus.tripCompletedSummary => TripRecord(
        id: request.id,
        clientName: request.clientName,
        pickup: request.pickup,
        dropOff: request.dropOff,
        distanceKm: request.distanceKm,
        fare: request.fare,
        estimatedDurationMinutes: request.estimatedDurationMinutes,
        startedAt: state.tripStartedAt,
        completedAt: DateTime.now(),
      ),
      _ => null,
    };

    final meta =
        '${westernDigits(request.distanceKm.toStringAsFixed(1))} ${'km_unit'.tr()}'
        '${request.estimatedDurationMinutes != null && request.estimatedDurationMinutes! > 0 ? ' · ${'trip_estimated_duration_inline'.tr(namedArgs: {'duration': _estimatedDurationValue(request.estimatedDurationMinutes)})}' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (summaryRecord != null) ...[
          _TripConclusionCard(record: summaryRecord, compact: compact),
          SizedBox(height: gap),
        ],
        if (state.tripStatus == TripStatus.headingToClient ||
            state.tripStatus == TripStatus.tripInProgress ||
            state.tripStatus == TripStatus.tripCompletedSummary ||
            state.tripStatus == TripStatus.awaitingClientRating) ...[
          _CompactClientRow(request: request, compact: compact),
          SizedBox(height: gap),
        ],
        if (state.tripStatus != TripStatus.tripCompletedSummary &&
            state.tripStatus != TripStatus.awaitingClientRating) ...[
          _DriverRouteEndpointsRow(
            pickup: request.pickup,
            dropOff: request.dropOff,
            onPickupTap: () => _openGoogleMapsLocation(request.pickupLatLng),
            onDropoffTap: () => _openGoogleMapsLocation(request.dropOffLatLng),
            compact: compact,
          ),
          SizedBox(height: gapSm),
          Text(
            meta,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 11 : null,
            ),
          ),
        ],
        if (state.tripStatus == TripStatus.tripInProgress) ...[
          SizedBox(height: compact ? 6 : 10),
          _VehicleInfoLine(
            truckType: state.profile?.truckType ?? '',
            vehiclePlate: state.profile?.vehiclePlate ?? '',
            vehicleColor: state.profile?.vehicleColor ?? '',
            vehicleModel: state.profile?.vehicleModel ?? '',
            compact: compact,
          ),
        ],
        SizedBox(height: gap),
        if (state.tripStatus == TripStatus.headingToClient)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: _denseFilled(context),
                  onPressed: notifier.confirmArrivedAtClient,
                  icon: Icon(
                    Icons.flag_circle_outlined,
                    size: compact ? 18 : 20,
                  ),
                  label: Text(
                    'driver_arrived_at_client'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'cancel_trip'.tr(),
                child: Material(
                  color: Colors.red.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.red.shade200),
                  ),
                  child: InkWell(
                    onTap: notifier.cancelActiveTrip,
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: compact ? 42 : 46,
                      height: compact ? 42 : 46,
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.red.shade800,
                        size: compact ? 22 : 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
        else if (state.tripStatus == TripStatus.tripInProgress)
          FilledButton.icon(
            style: _denseFilled(context),
            onPressed: notifier.completeTrip,
            icon: Icon(Icons.flag_outlined, size: compact ? 18 : 20),
            label: Text('complete_trip'.tr()),
          )
        else if (state.tripStatus == TripStatus.tripCompletedSummary)
          FilledButton.icon(
            style: _denseFilled(context),
            onPressed: notifier.confirmCashReceived,
            icon: Icon(Icons.payments_outlined, size: compact ? 18 : 20),
            label: Text('confirm_cash'.tr()),
          )
        else if (state.tripStatus == TripStatus.awaitingClientRating)
          FilledButton.icon(
            style: _denseFilled(context),
            onPressed: () => _openClientRatingBottomSheet(context),
            icon: Icon(Icons.star_rounded, size: compact ? 18 : 20),
            label: Text('rate_client'.tr()),
          ),
      ],
    );
  }

  Future<void> _openGoogleMapsLocation(LatLng location) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _CompactClientRow extends StatelessWidget {
  const _CompactClientRow({required this.request, this.compact = false});

  final TripRequest request;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = compact ? 18.0 : 22.0;
    final pad = compact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 10);
    return Material(
      color: AppColors.brandOrange.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(compact ? 12 : 14),
      child: Padding(
        padding: pad,
        child: Row(
          children: [
            CircleAvatar(
              radius: r,
              backgroundColor: AppColors.brandOrange.withValues(alpha: 0.2),
              child: Icon(
                Icons.person,
                color: AppColors.brandOrange,
                size: compact ? 20 : 24,
              ),
            ),
            SizedBox(width: compact ? 8 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (compact
                                ? Theme.of(context).textTheme.titleSmall
                                : Theme.of(context).textTheme.titleSmall)
                            ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (request.clientPhone.trim().isNotEmpty) ...[
                    SizedBox(height: compact ? 2 : 4),
                    Text(
                      request.clientPhone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: compact ? 11 : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (request.clientPhone.trim().isNotEmpty)
              IconButton(
                onPressed: () => _callClient(request.clientPhone),
                icon: Icon(Icons.phone, size: compact ? 20 : 24),
                color: AppColors.brandOrange,
                tooltip: 'call_client'.tr(),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _callClient(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }
}

class _VehicleInfoLine extends StatelessWidget {
  const _VehicleInfoLine({
    required this.truckType,
    required this.vehiclePlate,
    required this.vehicleColor,
    required this.vehicleModel,
    this.compact = false,
  });

  final String truckType;
  final String vehiclePlate;
  final String vehicleColor;
  final String vehicleModel;
  final bool compact;

  String _part(String labelKey, String value) {
    final v = value.trim();
    if (v.isEmpty) return '';
    return '${labelKey.tr()}: $v';
  }

  @override
  Widget build(BuildContext context) {
    final label = truckType == kTruckDoubleCabin
        ? 'truck_double_cabin'.tr()
        : 'truck_single_cabin'.tr();
    final parts = [
      '${'vehicle_line_type'.tr()}: $label',
      _part('vehicle_line_model', vehicleModel),
      _part('vehicle_line_color', vehicleColor),
      _part('vehicle_line_plate', vehiclePlate),
    ].where((p) => p.isNotEmpty).join(' · ');
    return Row(
      children: [
        Icon(
          Icons.local_shipping_outlined,
          color: AppColors.brandOrange,
          size: compact ? 18 : 24,
        ),
        SizedBox(width: compact ? 6 : 8),
        Expanded(
          child: Text(
            parts,
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: compact ? 11.5 : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _TripConclusionCard extends StatelessWidget {
  const _TripConclusionCard({required this.record, this.compact = false});

  final TripRecord record;
  final bool compact;

  String _formatDuration(DateTime? start, DateTime end) {
    if (start == null) return '—';
    final d = end.difference(start);
    if (d.inHours >= 1) {
      return '${d.inHours} ${'trip_unit_hours'.tr()} ${d.inMinutes.remainder(60)} ${'trip_unit_minutes'.tr()}';
    }
    if (d.inMinutes >= 1) {
      return '${d.inMinutes} ${'trip_unit_minutes'.tr()}';
    }
    return '${d.inSeconds} ${'trip_unit_seconds'.tr()}';
  }

  Widget _buildCompactLayout(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: AppColors.brandOrange.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.brandOrange.withValues(alpha: 0.5),
          width: 1,
        ),
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
                const Icon(
                  Icons.route_rounded,
                  color: AppColors.brandOrange,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'trip_summary_title'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  dzdCurrency().format(record.fare),
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
                    _formatDuration(record.startedAt, record.completedAt),
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
                    '${westernDigits(record.distanceKm.toStringAsFixed(1))} ${'trip_summary_km_unit'.tr()}',
                  ),
                ),
              ],
            ),
            if (record.estimatedDurationMinutes != null) ...[
              const SizedBox(height: 4),
              Text(
                '${'trip_estimated_duration_label'.tr()}: ${_estimatedDurationValue(record.estimatedDurationMinutes)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Divider(
              height: 1,
              color: AppColors.brandOrange.withValues(alpha: 0.22),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _compactAddr(
                    context,
                    'trip_summary_from_label'.tr(),
                    record.pickup,
                    const Color(0xFF2E7D32),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10, left: 4, right: 4),
                  child: Icon(
                    Directionality.of(context) == ui.TextDirection.rtl
                        ? Icons.arrow_back_rounded
                        : Icons.arrow_forward_rounded,
                    size: 16,
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                  ),
                ),
                Expanded(
                  child: _compactAddr(
                    context,
                    'trip_summary_to_label'.tr(),
                    record.dropOff,
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

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompactLayout(context);
    final pad = compact ? 10.0 : 16.0;
    final iconSize = compact ? 22.0 : 28.0;
    final rowPad = compact ? 5.0 : 10.0;
    return Card(
      color: AppColors.brandOrange.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        side: BorderSide(
          color: AppColors.brandOrange.withValues(alpha: 0.5),
          width: compact ? 1 : 1.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.route_rounded,
                  color: AppColors.brandOrange,
                  size: iconSize,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'trip_summary_title'.tr(),
                    style:
                        (compact
                                ? Theme.of(context).textTheme.titleSmall
                                : Theme.of(context).textTheme.titleMedium)
                            ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 8 : 12),
            _summaryRow(
              context,
              'trip_summary_duration_label'.tr(),
              _formatDuration(record.startedAt, record.completedAt),
              compact: compact,
              bottom: rowPad,
            ),
            if (record.estimatedDurationMinutes != null)
              _summaryRow(
                context,
                'trip_estimated_duration_label'.tr(),
                _estimatedDurationValue(record.estimatedDurationMinutes),
                compact: compact,
                bottom: rowPad,
              ),
            _summaryRow(
              context,
              'trip_summary_from_label'.tr(),
              record.pickup,
              compact: compact,
              bottom: rowPad,
            ),
            _summaryRow(
              context,
              'trip_summary_to_label'.tr(),
              record.dropOff,
              compact: compact,
              bottom: rowPad,
            ),
            _summaryRow(
              context,
              'trip_summary_distance_label'.tr(),
              '${westernDigits(record.distanceKm.toStringAsFixed(1))} ${'trip_summary_km_unit'.tr()}',
              compact: compact,
              bottom: rowPad,
            ),
            _summaryRow(
              context,
              'trip_summary_price_label'.tr(),
              dzdCurrency().format(record.fare),
              emphasize: true,
              compact: compact,
              bottom: rowPad,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context,
    String label,
    String value, {
    bool emphasize = false,
    bool compact = false,
    double bottom = 10,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                fontSize: compact ? 11 : null,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: compact ? 2 : 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                color: emphasize
                    ? AppColors.brandOrange
                    : AppColors.textPrimary,
                fontSize: compact ? 12 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showCitySelectionSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final state = ref.read(driverAppStateProvider);
  final currentLoc = state.driverLocation;
  final currentPick = currentLoc != null
      ? nearestSupportedNeighborhood(currentLoc.latitude, currentLoc.longitude)
      : NeighborhoodPick.defaultSupported;

  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (ctx) {
      final lang = ctx.locale.languageCode;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.brandOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.brandOrange,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'driver_select_city'.tr(),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: Colors.black.withValues(alpha: 0.08)),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: NeighborhoodPick.all.length,
                      itemBuilder: (context, index) {
                        final pick = NeighborhoodPick.all[index];
                        final isSelected = currentPick?.titleEn == pick.titleEn;
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.brandOrange.withValues(alpha: 0.12)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.brandOrange
                                  : Colors.black.withValues(alpha: 0.06),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(
                              Icons.location_city_rounded,
                              color: pick.supported
                                  ? (isSelected
                                        ? AppColors.brandOrange
                                        : AppColors.textSecondary)
                                  : Colors.grey.shade400,
                            ),
                            title: Text(
                              pick.labelForLocale(lang),
                              style: TextStyle(
                                color: pick.supported
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary.withValues(
                                        alpha: 0.5,
                                      ),
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.brandOrange,
                                  )
                                : null,
                            onTap: pick.supported
                                ? () {
                                    Navigator.of(ctx).pop();
                                    ref
                                        .read(driverAppStateProvider.notifier)
                                        .refreshDriverLocation(
                                          sendToServer: true,
                                        );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'driver_city_updated'.tr(
                                            namedArgs: {
                                              'city': pick.labelForLocale(lang),
                                            },
                                          ),
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _DriverCityPill extends StatelessWidget {
  const _DriverCityPill({required this.location, required this.onTap});

  final LatLng? location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final pick = location != null
        ? nearestSupportedNeighborhood(location!.latitude, location!.longitude)
        : NeighborhoodPick.defaultSupported;
    final label = pick?.labelForLocale(lang) ?? 'Tamanrasset Center';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on_rounded,
              color: AppColors.brandOrange,
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.brandOrange,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.brandOrange,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
