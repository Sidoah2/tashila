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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 10,
            vertical: compact ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandOrange.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(compact ? 12 : 16),
            border: Border.all(
              color: selected ? AppColors.brandOrange : AppColors.textSecondary.withValues(alpha: 0.25),
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: compact ? 44 : 68,
                child: Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                ),
              ),
              SizedBox(height: compact ? 4 : 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: (compact
                        ? theme.textTheme.labelMedium
                        : theme.textTheme.titleSmall)
                    ?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.brandOrange : AppColors.textPrimary,
                      fontSize: compact ? 12 : null,
                    ),
              ),
              SizedBox(height: compact ? 4 : 6),
              Text(
                loadKey.tr(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      fontSize: compact ? 10 : null,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
