import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tashila_client/core/state/app_state.dart';
import 'package:tashila_client/core/theme/app_colors.dart';

/// Customer-visible steps for the transport flow.
class TripStageIndicator extends StatelessWidget {
  const TripStageIndicator({
    super.key,
    required this.stage,
    this.compact = false,
  });

  final TripStage stage;
  final bool compact;

  static int stageIndex(TripStage s) => switch (s) {
        TripStage.idle => -1,
        TripStage.searchingDriver => 0,
        TripStage.noDriversFound => -1,
        TripStage.driverEnRoute => 1,
        TripStage.tripStarted => 2,
        TripStage.awaitingPayment => 3,
        TripStage.arrivedSummary => 3,
      };

  @override
  Widget build(BuildContext context) {
    final idx = stageIndex(stage);
    const keys = [
      'trip_stage_find_driver',
      'trip_stage_en_route',
      'trip_stage_trip_started',
      'trip_stage_arrived',
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final stepWidth = constraints.maxWidth / keys.length;
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            // Background line (inactive timeline track)
            Positioned(
              top: compact ? 12 : 15,
              left: stepWidth / 2,
              right: stepWidth / 2,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            // Active timeline track (growing line)
            if (idx > 0)
              Positioned(
                top: compact ? 12 : 15,
                left: stepWidth / 2,
                width: stepWidth * math.min(idx, keys.length - 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: AppColors.brandOrange,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            // Nodes & Labels
            Row(
              children: List.generate(keys.length, (i) {
                return Expanded(
                  child: _StageStep(
                    label: keys[i].tr(),
                    index: i,
                    activeIndex: idx,
                    compact: compact,
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

class _StageStep extends StatelessWidget {
  const _StageStep({
    required this.label,
    required this.index,
    required this.activeIndex,
    this.compact = false,
  });

  final String label;
  final int index;
  final int activeIndex;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final past = activeIndex > index;
    final current = activeIndex == index;
    final dim = compact ? 24.0 : 30.0;
    final iconSize = compact ? 14.0 : 16.0;

    final Widget circleChild;
    final BoxDecoration decoration;

    if (past) {
      circleChild = Icon(Icons.check_rounded, color: Colors.white, size: iconSize - 2);
      decoration = const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brandOrange,
      );
    } else if (current) {
      circleChild = Container(
        width: compact ? 8 : 10,
        height: compact ? 8 : 10,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      );
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brandOrange,
        boxShadow: [
          BoxShadow(
            color: AppColors.brandOrange.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 3,
          )
        ],
      );
    } else {
      circleChild = const SizedBox.shrink();
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.08),
          width: 2,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dim,
          height: dim,
          decoration: decoration,
          alignment: Alignment.center,
          child: circleChild,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: compact ? 10 : 11.5,
                  fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                  height: 1.2,
                  color: current || past
                      ? AppColors.textPrimary
                      : AppColors.textSecondary.withValues(alpha: 0.7),
                ),
          ),
        ),
      ],
    );
  }
}
