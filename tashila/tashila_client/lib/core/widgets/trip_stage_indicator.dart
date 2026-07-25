import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tashila_client/core/formatting/app_format.dart';
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0)
            Padding(
              padding: EdgeInsets.only(top: compact ? 10 : 13),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: compact ? 2 : 3,
                width: compact ? 6 : 8,
                decoration: BoxDecoration(
                  color: idx >= i
                      ? AppColors.brandOrange
                      : AppColors.textSecondary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Expanded(
            child: _StageStep(
              label: keys[i].tr(),
              index: i,
              activeIndex: idx,
              compact: compact,
            ),
          ),
        ],
      ],
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
    final fontSize = compact ? 11.0 : 13.0;
    final iconSize = compact ? 14.0 : 16.0;

    final Widget circleChild;
    final BoxDecoration decoration;
    if (past) {
      circleChild = Icon(Icons.check, color: Colors.white, size: iconSize);
      decoration = const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brandOrange,
      );
    } else if (current) {
      circleChild = Text(
        ltrNumber('${index + 1}'),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
        ),
      );
      decoration = const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brandOrange,
      );
    } else {
      circleChild = Text(
        ltrNumber('${index + 1}'),
        style: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.85),
          fontWeight: FontWeight.w600,
          fontSize: fontSize,
        ),
      );
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.35),
          width: compact ? 1.5 : 2,
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: dim,
          height: dim,
          decoration: decoration,
          alignment: Alignment.center,
          child: circleChild,
        ),
        SizedBox(height: compact ? 4 : 6),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: compact ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: (Theme.of(context).textTheme.labelSmall?.fontSize ??
                        11) -
                    (compact ? 1 : 0.5),
                fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                height: compact ? 1.1 : 1.2,
                color: current || past
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}
