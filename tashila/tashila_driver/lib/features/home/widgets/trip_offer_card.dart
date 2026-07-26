import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/formatting/app_format.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import 'offer_countdown_ring.dart';

String _durationPart(int? minutes) {
  if (minutes == null || minutes <= 0) return '';
  return 'trip_estimated_duration_inline'.tr(
    namedArgs: {
      'duration': '${westernDigits('$minutes')} ${'trip_unit_minutes'.tr()}',
    },
  );
}

/// Single trip request with an integrated live countdown ring.
class TripOfferCard extends StatelessWidget {
  const TripOfferCard({
    super.key,
    required this.offer,
    required this.onAccept,
    required this.onReject,
    this.isPrimary = false,
    this.acceptEnabled = true,
    this.vehiclePlate = '',
    this.vehicleColor = '',
    this.vehicleModel = '',
  });

  final IncomingOffer offer;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool isPrimary;
  final bool acceptEnabled;
  final String vehiclePlate;
  final String vehicleColor;
  final String vehicleModel;

  String _truckLabel(String type) {
    return type == kTruckDoubleCabin
        ? 'truck_double_cabin'.tr()
        : 'truck_single_cabin'.tr();
  }

  String _vehicleSummary() {
    final parts = <String>[];
    final model = vehicleModel.trim();
    final color = vehicleColor.trim();
    final plate = vehiclePlate.trim();
    if (model.isNotEmpty) parts.add(model);
    if (color.isNotEmpty) parts.add(color);
    if (plate.isNotEmpty) parts.add(plate);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final request = offer.request;
    final seconds = offer.remainingSeconds;
    final critical = seconds <= 3;
    final urgent = seconds <= 8;

    final borderColor = critical
        ? const Color(0xFFD32F2F)
        : urgent
        ? AppColors.brandOrange
        : isPrimary
        ? AppColors.brandOrange.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.08);

    final meta = StringBuffer()
      ..write(
        '${westernDigits(request.distanceKm.toStringAsFixed(1))} ${'km_unit'.tr()}',
      );
    if (offer.pickupDistanceKm != null && offer.pickupDistanceKm! > 0) {
      meta.write(
        ' · ${'offer_pickup_distance'.tr(namedArgs: {'km': westernDigits(offer.pickupDistanceKm!.toStringAsFixed(1))})}',
      );
    }
    if (request.estimatedDurationMinutes != null &&
        request.estimatedDurationMinutes! > 0) {
      meta.write(' · ${_durationPart(request.estimatedDurationMinutes)}');
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isPrimary ? Colors.white : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: isPrimary ? 2 : 1),
        boxShadow: [
          if (isPrimary)
            BoxShadow(
              color: AppColors.brandOrange.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OfferCountdownRing(offer: offer, size: isPrimary ? 72 : 64),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isPrimary) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brandOrange,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'offer_card_priority'.tr(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              request.clientName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            dzdCurrency().format(request.fare),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.brandOrange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _RouteTimeline(
                        pickup: request.pickup,
                        dropOff: request.dropOff,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        meta.toString(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (request.truckType.isNotEmpty ||
                          _vehicleSummary().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (request.truckType.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brandOrange.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.brandOrange.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  _truckLabel(request.truckType),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.brandOrange,
                                  ),
                                ),
                              ),
                            if (_vehicleSummary().isNotEmpty)
                              Text(
                                _vehicleSummary(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (urgent) ...[
                        const SizedBox(height: 6),
                        Text(
                          critical
                              ? 'offer_expires_critical'.tr()
                              : 'offer_expires_soon'.tr(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: critical
                                ? const Color(0xFFD32F2F)
                                : const Color(0xFFE65100),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC62828),
                        side: const BorderSide(
                          color: Color(0xFFE57373),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'reject'.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    label: seconds <= 0 ? 'offer_expired'.tr() : 'accept'.tr(),
                    icon: Icons.check_rounded,
                    onPressed: acceptEnabled && seconds > 0 ? onAccept : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteTimeline extends StatelessWidget {
  const _RouteTimeline({required this.pickup, required this.dropOff});

  final String pickup;
  final String dropOff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF43A047),
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  color: AppColors.textSecondary.withValues(alpha: 0.25),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.brandOrange,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pickup,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Text(
                  dropOff,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
