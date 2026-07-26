import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tashila_client/core/state/app_state.dart';
import 'package:tashila_client/core/theme/app_colors.dart';

class TruckTypeCard extends StatelessWidget {
  const TruckTypeCard({
    super.key,
    required this.type,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final TruckType type;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  static const _singleAsset = 'assets/images/singlecabin_icon.png';
  static const _doubleAsset = 'assets/images/doublecabin_icon.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = type == TruckType.singleCabine ? 'single_cabine'.tr() : 'double_cabine'.tr();
    final asset = type == TruckType.singleCabine ? _singleAsset : _doubleAsset;
    final loadKey = type == TruckType.singleCabine
        ? 'truck_max_load_700kg'
        : 'truck_max_load_1400kg';

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.0, end: selected ? 1.03 : 1.0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(compact ? 14 : 18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: compact ? 10 : 16,
            ),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(compact ? 14 : 18),
              border: Border.all(
                color: selected ? AppColors.brandOrange : Colors.black.withValues(alpha: 0.05),
                width: selected ? 2.2 : 1.5,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.brandOrange.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: compact ? 48 : 72,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Image.asset(
                    asset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    gaplessPlayback: true,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (compact
                          ? theme.textTheme.labelMedium
                          : theme.textTheme.titleSmall)
                      ?.copyWith(
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? AppColors.brandOrange : AppColors.textPrimary,
                        fontSize: compact ? 13 : 14,
                        letterSpacing: -0.2,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  loadKey.tr(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                        fontSize: compact ? 9.5 : 11,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
