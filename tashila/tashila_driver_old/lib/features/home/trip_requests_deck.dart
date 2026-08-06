import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/formatting/app_format.dart';
import '../../core/models/models.dart';
import '../../core/state/driver_app_state.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/trip_offer_card.dart';

/// Bottom deck listing trip offers — each card carries its own countdown.
class TripRequestsDeck extends StatelessWidget {
  const TripRequestsDeck({
    super.key,
    required this.offers,
    required this.notifier,
    required this.countdownTick,
    this.errorText,
    this.isBusy = false,
    this.vehiclePlate = '',
    this.vehicleColor = '',
    this.vehicleModel = '',
  });

  final List<IncomingOffer> offers;
  final DriverAppNotifier notifier;
  final int countdownTick;
  final String? errorText;
  final bool isBusy;
  final String vehiclePlate;
  final String vehicleColor;
  final String vehicleModel;

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable — forces rebuild each second from parent state
    final _ = countdownTick;
    final theme = Theme.of(context);
    final sorted = List<IncomingOffer>.from(offers)
      ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    final primaryId = sorted.isNotEmpty ? sorted.first.request.id : null;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.52;

    return Material(
      elevation: 20,
      shadowColor: Colors.black45,
      color: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.brandOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: AppColors.brandOrange,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'requests_deck_title'.tr(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'requests_deck_subtitle'.tr(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandOrange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      westernDigits('${sorted.length}'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => notifier.refreshNearbyRequests(),
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'refresh_requests'.tr(),
                  ),
                ],
              ),
            ),
            if ((errorText ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Material(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      errorText ?? '',
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                physics: const BouncingScrollPhysics(),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final offer = sorted[index];
                  final isPrimary = offer.request.id == primaryId;
                  return TripOfferCard(
                    offer: offer,
                    isPrimary: isPrimary,
                    acceptEnabled: !isBusy,
                    vehiclePlate: vehiclePlate,
                    vehicleColor: vehicleColor,
                    vehicleModel: vehicleModel,
                    onAccept: () => notifier.acceptRequest(offer.request),
                    onReject: () => notifier.rejectRequest(offer.request),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
