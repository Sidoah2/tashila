import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/map_config.dart';
import '../../core/data/neighborhoods.dart';
import '../../core/formatting/app_format.dart';
import '../../core/models/models.dart';
import '../../core/state/driver_app_state.dart';
import '../../core/theme/app_colors.dart';
import 'trip_requests_deck.dart';
import 'waiting_for_offer_card.dart';

String _estimatedDurationValue(int? minutes) {
  if (minutes == null || minutes <= 0) return '';
  return '${westernDigits('$minutes')} ${'trip_unit_minutes'.tr()}';
}

Future<void> _openClientRatingBottomSheet(BuildContext context) async {
  context.go('/rate-client');
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

    ref.listen(driverAppStateProvider, (previous, next) {
      if (next.infoMessage != null &&
          next.infoMessage != previous?.infoMessage) {
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: Colors.white,
            elevation: 10,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      size: 32,
                      color: AppColors.brandOrange,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'trip_cancelled_title'.tr(),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    next.infoMessage!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.35,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        notifier.clearInfoMessage();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandOrange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'ok'.tr(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    });

    print("locale:" + Localizations.localeOf(context).languageCode);

    return PopScope(
      canPop: state.tripStatus != TripStatus.awaitingClientRating,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (state.tripStatus == TripStatus.awaitingClientRating) {
          _openClientRatingBottomSheet(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: true,

        body: Stack(
          fit: StackFit.expand,
          children: [
            _MapLayer(),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    if (isIdlePhase) ...[
                      Directionality(
                        textDirection:
                            Localizations.localeOf(context).languageCode == 'ar'
                            ? ui.TextDirection.ltr
                            : ui.TextDirection.rtl,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color:
                                state.availability == AvailabilityStatus.online
                                ? const Color(0xFFDCFCE7)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color:
                                  state.availability ==
                                      AvailabilityStatus.online
                                  ? const Color(0xFF86EFAC)
                                  : Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Left side: ON/OFF Button
                              InkWell(
                                onTap: documentsApproved
                                    ? () => notifier.setAvailability(
                                        state.availability ==
                                                AvailabilityStatus.online
                                            ? AvailabilityStatus.offline
                                            : AvailabilityStatus.online,
                                      )
                                    : null,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        state.availability ==
                                            AvailabilityStatus.online
                                        ? const Color(0xFF22C55E)
                                        : Colors.grey.shade600,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      if (state.availability ==
                                          AvailabilityStatus.online)
                                        BoxShadow(
                                          color: const Color(
                                            0xFF22C55E,
                                          ).withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.power_settings_new_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        state.availability ==
                                                AvailabilityStatus.online
                                            ? 'online'.tr()
                                            : 'offline'.tr(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Right side: State Label info
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'availability_label'.tr(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          state.availability ==
                                              AvailabilityStatus.online
                                          ? const Color(0xFF166534)
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        !documentsApproved
                                            ? 'documents_not_approved_online'
                                                  .tr()
                                            : state.availability ==
                                                  AvailabilityStatus.online
                                            ? 'online'.tr()
                                            : 'offline'.tr(),
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              state.availability ==
                                                  AvailabilityStatus.online
                                              ? const Color(0xFF15803D)
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color:
                                              state.availability ==
                                                  AvailabilityStatus.online
                                              ? const Color(0xFF22C55E)
                                              : Colors.grey.shade400,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (showWaitingForOffer) ...[
                      const SizedBox(height: 8),
                      const WaitingForOfferCard(),
                    ],
                    const Spacer(),
                  ],
                ),
              ),
            ),

            // ── GPS TARGET LOCATOR BUTTON ──
            // Positioned(
            //   bottom: 90,
            //   right: 16,
            //   child: Container(
            //     decoration: BoxDecoration(
            //       color: Colors.white,
            //       shape: BoxShape.circle,
            //       border: Border.all(color: Colors.grey.shade200),
            //       boxShadow: [
            //         BoxShadow(
            //           color: Colors.black.withValues(alpha: 0.12),
            //           blurRadius: 10,
            //           offset: const Offset(0, 3),
            //         ),
            //       ],
            //     ),
            //     child: IconButton(
            //       icon: const Icon(
            //         Icons.my_location_rounded,
            //         color: AppColors.textPrimary,
            //         size: 20,
            //       ),
            //       onPressed: () {
            //         final loc = state.driverLocation;
            //         if (loc != null) {
            //           notifier.refreshDriverLocation(sendToServer: false);
            //         }
            //       },
            //     ),
            //   ),
            // ),

            // ── IDLE PHASE CARDS (STATUS + WAITING) ──
            // if (isIdlePhase)
            //   Positioned(
            //     top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
            //     left: 14,
            //     right: 14,
            //     child: Column(
            //       children: [
            //         // Status Card (Light Green Container)
            //         Container(
            //           padding: const EdgeInsets.symmetric(
            //             horizontal: 16,
            //             vertical: 14,
            //           ),
            //           decoration: BoxDecoration(
            //             color: state.availability == AvailabilityStatus.online
            //                 ? const Color(0xFFDCFCE7)
            //                 : Colors.grey.shade100,
            //             borderRadius: BorderRadius.circular(22),
            //             border: Border.all(
            //               color: state.availability == AvailabilityStatus.online
            //                   ? const Color(0xFF86EFAC)
            //                   : Colors.grey.shade300,
            //             ),
            //           ),
            //           child: Row(
            //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //             children: [
            //               Column(
            //                 crossAxisAlignment: CrossAxisAlignment.start,
            //                 mainAxisSize: MainAxisSize.min,
            //                 children: [
            //                   Text(
            //                     'availability_label'.tr(),
            //                     style: TextStyle(
            //                       fontSize: 13,
            //                       fontWeight: FontWeight.bold,
            //                       color:
            //                           state.availability ==
            //                               AvailabilityStatus.online
            //                           ? const Color(0xFF166534)
            //                           : Colors.grey.shade700,
            //                     ),
            //                   ),
            //                   const SizedBox(height: 4),
            //                   Row(
            //                     children: [
            //                       Container(
            //                         width: 10,
            //                         height: 10,
            //                         decoration: BoxDecoration(
            //                           color:
            //                               state.availability ==
            //                                   AvailabilityStatus.online
            //                               ? const Color(0xFF22C55E)
            //                               : Colors.grey,
            //                           shape: BoxShape.circle,
            //                         ),
            //                       ),
            //                       const SizedBox(width: 6),
            //                       Text(
            //                         !documentsApproved
            //                             ? 'documents_not_approved_online'.tr()
            //                             : state.availability ==
            //                                   AvailabilityStatus.online
            //                             ? 'online'.tr()
            //                             : 'offline'.tr(),
            //                         style: TextStyle(
            //                           fontSize: 14,
            //                           fontWeight: FontWeight.w800,
            //                           color:
            //                               state.availability ==
            //                                   AvailabilityStatus.online
            //                               ? const Color(0xFF15803D)
            //                               : Colors.grey.shade700,
            //                         ),
            //                       ),
            //                     ],
            //                   ),
            //                 ],
            //               ),
            //               ElevatedButton.icon(
            //                 onPressed: documentsApproved
            //                     ? () => notifier.setAvailability(
            //                         state.availability ==
            //                                 AvailabilityStatus.online
            //                             ? AvailabilityStatus.offline
            //                             : AvailabilityStatus.online,
            //                       )
            //                     : null,
            //                 icon: const Icon(
            //                   Icons.power_settings_new_rounded,
            //                   size: 18,
            //                   color: Colors.white,
            //                 ),
            //                 label: Text(
            //                   state.availability == AvailabilityStatus.online
            //                       ? 'online'.tr()
            //                       : 'offline'.tr(),
            //                   style: const TextStyle(
            //                     fontWeight: FontWeight.w800,
            //                     fontSize: 13.5,
            //                     color: Colors.white,
            //                   ),
            //                 ),
            //                 style: ElevatedButton.styleFrom(
            //                   backgroundColor:
            //                       state.availability ==
            //                           AvailabilityStatus.online
            //                       ? const Color(0xFF22C55E)
            //                       : Colors.grey.shade600,
            //                   elevation: 0,
            //                   padding: const EdgeInsets.symmetric(
            //                     horizontal: 16,
            //                     vertical: 10,
            //                   ),
            //                   shape: RoundedRectangleBorder(
            //                     borderRadius: BorderRadius.circular(14),
            //                   ),
            //                 ),
            //               ),
            //             ],
            //           ),
            //         ),

            //         if (showWaitingForOffer) ...[
            //           const SizedBox(height: 12),
            //           const WaitingForOfferCard(),
            //         ],
            //       ],
            //     ),
            //   ),
            if (!isIdlePhase && activeRequest != null)
              if (state.tripStatus == TripStatus.headingToClient ||
                  state.tripStatus == TripStatus.tripInProgress ||
                  state.tripStatus == TripStatus.tripCompletedSummary ||
                  state.tripStatus == TripStatus.awaitingClientRating)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _ActiveTripPanel(
                    request: activeRequest,
                    state: state,
                    notifier: notifier,
                    compact: true,
                  ),
                )
              else
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 20,
                  child: _GlassCard(
                    padding: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: _ActiveTripPanel(
                        request: activeRequest,
                        state: state,
                        notifier: notifier,
                        compact: true,
                      ),
                    ),
                  ),
                ),
            if (showOffersDeck)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
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
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
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
      final List<LatLng> points;
      if (state.polylinePoints.isNotEmpty) {
        points = state.polylinePoints;
      } else {
        final mid = LatLng(
          (routeRequest.pickupLatLng.latitude +
                  routeRequest.dropOffLatLng.latitude) /
              2,
          (routeRequest.pickupLatLng.longitude +
                  routeRequest.dropOffLatLng.longitude) /
              2,
        );
        points = [routeRequest.pickupLatLng, mid, routeRequest.dropOffLatLng];
      }
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          width: 4,
          color: AppColors.brandOrange,
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: target, zoom: _mapZoom),
      gestureRecognizers: _gestures,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
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

class _ActiveTripPanel extends StatefulWidget {
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

  @override
  State<_ActiveTripPanel> createState() => _ActiveTripPanelState();
}

class _ActiveTripPanelState extends State<_ActiveTripPanel> {
  bool _expanded = false;

  String _formatTimer(DateTime? start) {
    if (start == null) return '00:00:00';
    final diff = DateTime.now().difference(start);
    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (diff.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Future<void> _openGoogleMapsLocation(LatLng location) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _callClient(String phone) async {
    if (phone.trim().isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  Future<void> _smsClient(String phone) async {
    if (phone.trim().isEmpty) return;
    final uri = Uri(scheme: 'sms', path: phone);
    await launchUrl(uri);
  }

  Widget _buildActiveTripStage({
    required TripRequest request,
    required DriverAppState state,
    required DriverAppNotifier notifier,
    String? addressLabel,
    String? addressText,
    bool showCallClient = true,
    bool showCancelButton = true,
    required String buttonText,
    required VoidCallback onButtonPressed,
  }) {
    final ratingVal = request.clientRating ?? 5.0;

    final callButton = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: request.clientPhone.trim().isNotEmpty
            ? () => _callClient(request.clientPhone)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6F8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.phone_rounded,
                size: 16,
                color: AppColors.brandOrange,
              ),
              const SizedBox(width: 6),
              Text(
                'call_client'.tr(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── TOP FLOATING CLIENT DETAILS CARD ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Directionality(
              textDirection: ui.TextDirection.ltr,
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── LEFT SIDE: PROFILE PICTURE ──
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 72,
                          height: 80,
                          color: AppColors.brandOrange.withValues(alpha: 0.12),
                          child:
                              request.clientAvatar != null &&
                                  request.clientAvatar!.trim().isNotEmpty
                              ? Image.network(
                                  request.clientAvatar!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person_rounded,
                                    size: 44,
                                    color: AppColors.brandOrange,
                                  ),
                                )
                              : const Icon(
                                  Icons.person_rounded,
                                  size: 44,
                                  color: AppColors.brandOrange,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // ── RIGHT SIDE: DETAILS & RATING (In app locale direction) ──
                      Expanded(
                        child: Directionality(
                          textDirection: Directionality.of(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Client Name & Rating Badge Row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      request.clientName.isNotEmpty
                                          ? request.clientName
                                          : 'client_label'.tr(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              // 5 Stars Client Rating Row
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(5, (index) {
                                  final starNum = index + 1;
                                  IconData iconData;
                                  Color iconColor;
                                  if (ratingVal >= starNum) {
                                    iconData = Icons.star_rounded;
                                    iconColor = const Color(0xFFFFB800);
                                  } else if (ratingVal >= starNum - 0.5) {
                                    iconData = Icons.star_half_rounded;
                                    iconColor = const Color(0xFFFFB800);
                                  } else {
                                    iconData = Icons.star_rounded;
                                    iconColor = Colors.grey.shade300;
                                  }
                                  return Icon(
                                    iconData,
                                    size: 18,
                                    color: iconColor,
                                  );
                                }),
                              ),
                              if (addressLabel != null &&
                                  addressText != null) ...[
                                const SizedBox(height: 8),
                                // Location Address Label & Text
                                Text(
                                  addressLabel,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  addressText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (showCallClient) ...[
                    const SizedBox(height: 12),
                    // Call Client Action Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (showCancelButton) ...[
                          callButton,
                        ] else ...[
                          Expanded(child: callButton),
                        ],
                        if (showCancelButton) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  notifier.cancelActiveTrip();
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F6F8),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'cancel'.tr(),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── BOTTOM CONTAINER ROUNDED FROM TOP WITH BUTTON ──
        Container(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(context).padding.bottom + 16,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Handle Bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Primary Action Button ("وصلت لموقع العميل" / "إكمال الرحلة")
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: state.isBusy ? null : onButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    disabledBackgroundColor: AppColors.brandOrange.withValues(
                      alpha: 0.4,
                    ),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: state.isBusy
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          buttonText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTripCompletedSummaryStage({
    required TripRequest request,
    required DriverAppState state,
    required DriverAppNotifier notifier,
  }) {
    final String timerDisplay;
    if (request.startedAt != null && request.completedAt != null) {
      final diff = request.completedAt!.difference(request.startedAt!);
      final hours = diff.inHours.toString().padLeft(2, '0');
      final minutes = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
      if (diff.inHours > 0) {
        timerDisplay = '$hours:$minutes:$seconds';
      } else {
        timerDisplay = '$minutes:$seconds';
      }
    } else if (state.tripStartedAt != null) {
      timerDisplay = _formatTimer(state.tripStartedAt);
    } else {
      timerDisplay = '${request.estimatedDurationMinutes ?? 15} min';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── TOP FLOATING TRIP SUMMARY CARD ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── TOTAL FINAL PRICE BADGE ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandOrange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.brandOrange.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'total_price_label'.tr(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        formatTripPrice(request.fare),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.brandOrange,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    const Icon(
                      Icons.route_rounded,
                      size: 18,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'trip_length_label'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    Directionality(
                      textDirection: ui.TextDirection.ltr,
                      child: Text(
                        '${westernDigits(request.distanceKm.toStringAsFixed(1))} km',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 18,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'trip_duration'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    Directionality(
                      textDirection: ui.TextDirection.ltr,
                      child: Text(
                        timerDisplay,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: Colors.grey.shade200, height: 1),
                const SizedBox(height: 12),

                // ── START LOCATION (PICKUP) ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'pickup_point_label'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            request.pickup,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── END LOCATION (DROPOFF) ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.brandOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'dropoff_point_label'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            request.dropOff,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── BOTTOM CONTAINER ROUNDED FROM TOP WITH CONFIRM BUTTON ──
        Container(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(context).padding.bottom + 16,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Handle Bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Primary Action Button ("تأكيد استلام المبلغ")
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: state.isBusy ? null : notifier.confirmCashReceived,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    disabledBackgroundColor: AppColors.brandOrange.withValues(
                      alpha: 0.4,
                    ),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: state.isBusy
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'rate_client'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final state = widget.state;
    final notifier = widget.notifier;

    if (state.tripStatus == TripStatus.headingToClient) {
      return _buildActiveTripStage(
        request: request,
        state: state,
        notifier: notifier,
        addressLabel: "pickup_point_label".tr(),
        addressText: request.pickup,
        buttonText: 'driver_arrived_at_client'.tr(),
        onButtonPressed: notifier.confirmArrivedAtClient,
        showCancelButton: true,
      );
    }

    if (state.tripStatus == TripStatus.tripInProgress) {
      return _buildActiveTripStage(
        request: request,
        state: state,
        notifier: notifier,
        addressLabel: "dropoff_point_label".tr(),
        addressText: request.dropOff,
        buttonText: 'complete_trip'.tr(),
        onButtonPressed: notifier.completeTrip,
        showCancelButton: false,
      );
    }

    if (state.tripStatus == TripStatus.tripCompletedSummary) {
      return _buildTripCompletedSummaryStage(
        request: request,
        state: state,
        notifier: notifier,
      );
    }

    if (state.tripStatus == TripStatus.awaitingClientRating) {
      return const SizedBox.shrink();
    }

    final String buttonLabel;
    final IconData buttonIcon;
    final VoidCallback? onPrimaryPressed;

    switch (state.tripStatus) {
      case TripStatus.headingToClient:
        buttonLabel = 'driver_arrived_at_client'.tr();
        buttonIcon = Icons.navigation_rounded;
        onPrimaryPressed = notifier.confirmArrivedAtClient;
        break;
      case TripStatus.tripInProgress:
        buttonLabel = 'complete_trip'.tr();
        buttonIcon = Icons.check_rounded;
        onPrimaryPressed = notifier.completeTrip;
        break;
      case TripStatus.tripCompletedSummary:
        buttonLabel = 'rate_client'.tr();
        buttonIcon = Icons.star_rounded;
        onPrimaryPressed = notifier.confirmCashReceived;
        break;
      case TripStatus.awaitingClientRating:
        buttonLabel = 'rate_client'.tr();
        buttonIcon = Icons.star_rounded;
        onPrimaryPressed = () => _openClientRatingBottomSheet(context);
        break;
      default:
        buttonLabel = 'continue'.tr();
        buttonIcon = Icons.arrow_forward_rounded;
        onPrimaryPressed = null;
    }

    final timerDisplay = state.tripStartedAt != null
        ? _formatTimer(state.tripStartedAt)
        : '${request.estimatedDurationMinutes ?? 14} min';

    final timerSubtitle = state.tripStartedAt != null
        ? 'trip_duration'.tr()
        : 'appointment_time'.tr();

    final vehicleSummary = [
      state.profile?.vehicleModel.trim(),
      state.profile?.vehicleColor.trim(),
      state.profile?.vehiclePlate.trim(),
    ].where((s) => s != null && s.isNotEmpty).join(' · ');

    final clientSubtitle = vehicleSummary.isNotEmpty
        ? 'Pickup · $vehicleSummary'
        : 'Pickup · ${request.pickup}';

    final activeAddress = state.tripStatus == TripStatus.headingToClient
        ? request.pickup
        : request.dropOff;

    final activeLatLng = state.tripStatus == TripStatus.headingToClient
        ? request.pickupLatLng
        : request.dropOffLatLng;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── CLIENT INFO ROW ──
        Row(
          children: [
            Container(width: 1, height: 50, color: AppColors.brandOrange),
            SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Text(
                    request.clientName.isNotEmpty
                        ? request.clientName
                        : 'Client',

                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Spacer(),
                  // Circular Phone Call Button (Matching Screenshot)
                  if (request.clientPhone.trim().isNotEmpty)
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _callClient(request.clientPhone),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.12),
                            ),
                          ),
                          child: const Icon(
                            Icons.phone_outlined,
                            color: AppColors.brandOrange,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  SizedBox(width: 4),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.brandOrange.withValues(
                      alpha: 0.15,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppColors.brandOrange,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // ── ADDRESS LOCATION ROW ──
        // ── VERTICAL ROUTE MAPS LINE (Matching Screenshot using Real Data) ──
        Row(
          children: [
            Container(width: 1, height: 120, color: AppColors.brandOrange),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                spacing: 8,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'earnings_trip_detail_title'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  // Pickup Row (Black Pin + Real Pickup Address)
                  InkWell(
                    onTap: () => _openGoogleMapsLocation(request.pickupLatLng),
                    borderRadius: BorderRadius.circular(8),
                    child: Text(
                      request.pickup,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  Text(
                    "To".tr(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),

                  // Dropoff Row (Red Pin + Real Dropoff Address)
                  InkWell(
                    onTap: () => _openGoogleMapsLocation(request.dropOffLatLng),
                    borderRadius: BorderRadius.circular(8),
                    child: Text(
                      request.dropOff,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // ── EXPANDABLE DETAILS SECTION (Matching Screenshot) ──
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 1,
              height: _expanded ? 85 : 28,
              color: AppColors.brandOrange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'appointment_details'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey.shade700,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_expanded) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'distance'.tr(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          '${westernDigits(request.distanceKm.toStringAsFixed(1))} km',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'price'.tr(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          dzdCurrency().format(request.fare),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: state.isBusy ? null : onPrimaryPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: state.isBusy
                  ? AppColors.brandOrange.withValues(alpha: 0.65)
                  : AppColors.brandOrange,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandOrange.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.center,
            child: state.isBusy
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : Text(
                    buttonLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ],
    );
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
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
    return Container(
      child: Padding(
        padding: pad,
        child: Row(
          children: [
            CircleAvatar(
              radius: r,
              backgroundColor: AppColors.brandOrange.withValues(alpha: 0.15),
              child: Icon(
                Icons.person_rounded,
                color: AppColors.brandOrange,
                size: compact ? 20 : 24,
              ),
            ),
            SizedBox(width: compact ? 10 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (request.clientPhone.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '\u200E${request.clientPhone}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (request.clientPhone.trim().isNotEmpty)
              IconButton(
                onPressed: () => _callClient(request.clientPhone),
                icon: const Icon(Icons.phone_rounded, size: 20),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.brandOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.route_rounded,
                    color: AppColors.brandOrange,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'trip_summary_title'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  dzdCurrency().format(record.fare),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: AppColors.brandOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _compactKV(
                      context,
                      'trip_summary_duration_label'.tr(),
                      _formatDuration(record.startedAt, record.completedAt),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    width: 1,
                    height: 32,
                    color: Colors.black.withValues(alpha: 0.08),
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
            ),
            if (record.estimatedDurationMinutes != null) ...[
              const SizedBox(height: 8),
              Text(
                '${'trip_estimated_duration_label'.tr()}: ${_estimatedDurationValue(record.estimatedDurationMinutes)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Divider(height: 1, color: Colors.black.withValues(alpha: 0.06)),
            const SizedBox(height: 10),
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
                  padding: const EdgeInsets.only(top: 8, left: 6, right: 6),
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

// ─── DriverDrawer ─────────────────────────────────────────────────────────────

class DriverDrawer extends ConsumerWidget {
  const DriverDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverAppStateProvider);
    final profile = state.profile;
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return Drawer(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.black.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.brandOrange.withValues(
                      alpha: 0.15,
                    ),
                    child: Text(
                      (profile?.name ?? 'D').characters.first.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.brandOrange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.name.isNotEmpty == true
                              ? profile!.name
                              : 'Inconnu',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile?.phone.isNotEmpty == true
                              ? '\u200E${profile!.phone}'
                              : '\u200E${state.phone}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Drawer Items with Active State & Divider Lines (Matching Screenshot)
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DrawerTile(
                    icon: Icons.home_outlined,
                    title: 'Home',
                    isActive: currentRoute == '/home',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/home');
                    },
                  ),
                  _buildDivider(),
                  _DrawerTile(
                    icon: Icons.local_shipping_outlined,
                    title: 'Orders',
                    isActive: currentRoute == '/orders',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/orders');
                    },
                  ),
                  _buildDivider(),
                  _DrawerTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Profile',
                    isActive:
                        currentRoute == '/profile-view' ||
                        currentRoute == '/profile-edit',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/profile-view');
                    },
                  ),
                  _buildDivider(),
                  _DrawerTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Wallet',
                    isActive: currentRoute == '/earnings',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/earnings');
                    },
                  ),
                  _buildDivider(),
                  // _DrawerTile(
                  //   icon: Icons.account_balance_outlined,
                  //   title: 'Bank Details',
                  //   isActive: false,
                  //   onTap: () {
                  //     Navigator.pop(context);
                  //     context.push('/profile-view');
                  //   },
                  // ),
                  _buildDivider(),
                  _DrawerTile(
                    icon: Icons.translate_outlined,
                    title: 'Language',
                    isActive: currentRoute == '/language',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/language');
                    },
                  ),
                  _buildDivider(),
                  _DrawerTile(
                    icon: Icons.phone_outlined,
                    title: 'Contact Us',
                    isActive: currentRoute == '/support',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/support');
                    },
                  ),
                  _buildDivider(),
                  _DrawerTile(
                    icon: Icons.article_outlined,
                    title: 'profile_legal_terms_title'.tr(),
                    isActive: false,
                    onTap: () {
                      Navigator.pop(context);
                      _showLegalScrollDialog(
                        context,
                        'profile_legal_terms_title'.tr(),
                        'driver_legal_terms_body'.tr(),
                      );
                    },
                  ),
                  _buildDivider(),
                  _DrawerTile(
                    icon: Icons.shield_outlined,
                    title: 'profile_legal_privacy_title'.tr(),
                    isActive: false,
                    onTap: () {
                      Navigator.pop(context);
                      _showLegalScrollDialog(
                        context,
                        'profile_legal_privacy_title'.tr(),
                        'driver_legal_privacy_body'.tr(),
                      );
                    },
                  ),
                  _buildDivider(),
                  _DrawerTile(
                    icon: Icons.logout_rounded,
                    title: 'Log out',
                    isActive: false,
                    onTap: () {
                      final notifier = ref.read(
                        driverAppStateProvider.notifier,
                      );
                      Navigator.pop(context);
                      _confirmDriverLogout(context, notifier);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLegalScrollDialog(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            decoration: BoxDecoration(
              color: Colors.white,
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.article_rounded,
                        color: Colors.blue.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      body,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      ctx.locale.languageCode == 'ar'
                          ? 'أفهم وأوافق'
                          : (ctx.locale.languageCode == 'fr'
                                ? 'Compris'
                                : 'Close'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
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

  Widget _buildDivider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Divider(height: 1, color: Colors.black.withValues(alpha: 0.05)),
  );

  Future<void> _confirmDriverLogout(
    BuildContext context,
    DriverAppNotifier notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hero Red Logout Icon Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.brandOrange.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.logout_rounded,
                  size: 32,
                  color: AppColors.brandOrange,
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'logout_confirm_title'.tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Description
              Text(
                'logout_confirm_desc'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                          foregroundColor: Colors.grey.shade800,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          'cancel'.tr(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandOrange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'logout'.tr(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await notifier.logout();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.brandOrange;
    final inactiveColor = AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
      child: ListTile(
        dense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),

        leading: Icon(
          icon,
          color: isActive ? activeColor : inactiveColor,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? activeColor : AppColors.textPrimary,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            fontSize: 14.5,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  _DottedLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const dashHeight = 4.0;
    const dashSpace = 4.0;
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(0, startY),
        Offset(0, math.min(startY + dashHeight, size.height)),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
