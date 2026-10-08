import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/state/driver_app_state.dart';
import 'widgets/trip_offer_card.dart';

/// Non-scrollable active trip offer container on home screen.
class TripRequestsDeck extends StatefulWidget {
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
  State<TripRequestsDeck> createState() => _TripRequestsDeckState();
}

class _TripRequestsDeckState extends State<TripRequestsDeck> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable — forces rebuild each second from parent state
    final _ = widget.countdownTick;
    final sorted = List<IncomingOffer>.from(widget.offers)
      ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));

    if (sorted.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_selectedIndex >= sorted.length) {
      _selectedIndex = sorted.length - 1;
    }
    if (_selectedIndex < 0) {
      _selectedIndex = 0;
    }

    final activeOffer = sorted[_selectedIndex];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sorted.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: _selectedIndex > 0
                        ? () => setState(() => _selectedIndex--)
                        : null,
                  ),
                  Text(
                    'الطلبات المتوفرة (${_selectedIndex + 1} / ${sorted.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: _selectedIndex < sorted.length - 1
                        ? () => setState(() => _selectedIndex++)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        TripOfferCard(
          key: ValueKey(activeOffer.request.id),
          offer: activeOffer,
          isPrimary: true,
          acceptEnabled: !widget.isBusy,
          vehiclePlate: widget.vehiclePlate,
          vehicleColor: widget.vehicleColor,
          vehicleModel: widget.vehicleModel,
          onAccept: () => widget.notifier.acceptRequest(activeOffer.request),
          onReject: () => widget.notifier.rejectRequest(activeOffer.request),
          onRefresh: () => widget.notifier.refreshNearbyRequests(),
        ),
      ],
    );
  }
}
