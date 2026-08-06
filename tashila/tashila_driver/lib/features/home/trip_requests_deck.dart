import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/state/driver_app_state.dart';
import 'widgets/trip_offer_card.dart';

/// Non-scrollable active trip offer container on home screen.
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
    final sorted = List<IncomingOffer>.from(offers)
      ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));

    if (sorted.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeOffer = sorted.first;

    return TripOfferCard(
      offer: activeOffer,
      isPrimary: true,
      acceptEnabled: !isBusy,
      vehiclePlate: vehiclePlate,
      vehicleColor: vehicleColor,
      vehicleModel: vehicleModel,
      onAccept: () => notifier.acceptRequest(activeOffer.request),
      onReject: () => notifier.rejectRequest(activeOffer.request),
      onRefresh: () => notifier.refreshNearbyRequests(),
    );
  }
}
