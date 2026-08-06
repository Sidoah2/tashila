import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/formatting/app_format.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_colors.dart';

/// Single trip request offer card for driver waiting screen.
/// Renders dynamic offer data in light mode with title on right & circular timer on left in AR locale,
/// 2 metric capsules (trip length & gain), pickup/dropoff timeline, and Accept / Ignore buttons.
class TripOfferCard extends StatefulWidget {
  const TripOfferCard({
    super.key,
    required this.offer,
    required this.onAccept,
    required this.onReject,
    this.onRefresh,
    this.isPrimary = false,
    this.acceptEnabled = true,
    this.vehiclePlate = '',
    this.vehicleColor = '',
    this.vehicleModel = '',
  });

  final IncomingOffer offer;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback? onRefresh;
  final bool isPrimary;
  final bool acceptEnabled;
  final String vehiclePlate;
  final String vehicleColor;
  final String vehicleModel;

  @override
  State<TripOfferCard> createState() => _TripOfferCardState();
}

class _TripOfferCardState extends State<TripOfferCard> {
  bool _accepting = false;
  bool _rejecting = false;

  Future<void> _handleAccept() async {
    if (_accepting || _rejecting) return;
    setState(() => _accepting = true);
    try {
      widget.onAccept();
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _handleReject() async {
    if (_accepting || _rejecting) return;
    setState(() => _rejecting = true);
    try {
      widget.onReject();
    } finally {
      if (mounted) setState(() => _rejecting = false);
    }
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: AppColors.brandOrange),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final request = offer.request;
    final seconds = offer.remainingSeconds;
    final ttl = offer.ttlSeconds;
    final progress = ttl > 0 ? (seconds / ttl).clamp(0.0, 1.0) : 0.0;
    final isUrgent = seconds <= 10;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── TOP HEADER: TITLE ON RIGHT & CIRCLE TIMER ON LEFT (in AR/RTL) ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Title "طلب جديد" / "New Order" (RTL: Right side)
                Text(
                  'new_order_title'.tr(),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                // Circle Timer (RTL: Left side)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 54,
                      height: 54,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isUrgent
                              ? Colors.red.shade600
                              : AppColors.brandOrange,
                        ),
                      ),
                    ),
                    Text(
                      westernDigits('$seconds'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isUrgent ? Colors.red.shade700 : Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── METRICS CAPSULES (2 Containers: Trip Length & Gain) ──
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    icon: Icons.swap_calls_rounded,
                    label: 'trip_length_label'.tr(),
                    value:
                        '${westernDigits(request.distanceKm.toStringAsFixed(1))} ${'km_unit'.tr()}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    icon: Icons.payments_rounded,
                    label: 'trip_gain_label'.tr(),
                    value: formatTripPrice(request.fare),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── TIMELINE: START POINT & END POINT ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pickup / Start Point
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3B82F6),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'pickup_point_label'.tr(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              request.pickup,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Connector Line
                  Padding(
                    padding: const EdgeInsets.only(left: 5, right: 5),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      width: 2,
                      height: 24,
                      color: Colors.grey.shade300,
                    ),
                  ),

                  // Dropoff / End Point
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'dropoff_point_label'.tr(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              request.dropOff,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
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
            const SizedBox(height: 24),

            // ── ACTION BUTTONS: ACCEPT & IGNORE ──
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed:
                    (widget.acceptEnabled &&
                        seconds > 0 &&
                        !_accepting &&
                        !_rejecting)
                    ? _handleAccept
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandOrange,
                  disabledBackgroundColor: AppColors.brandOrange.withValues(
                    alpha: 0.4,
                  ),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: _accepting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        seconds <= 0
                            ? 'offer_expired'.tr()
                            : 'accept_order'.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: (_accepting || _rejecting) ? null : _handleReject,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  minimumSize: const Size(120, 36),
                ),
                child: _rejecting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.grey.shade600,
                        ),
                      )
                    : Text(
                        'ignore'.tr(),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.grey.shade600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
