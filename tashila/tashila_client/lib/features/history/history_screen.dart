import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tashila_client/core/state/app_state.dart';
import 'package:tashila_client/core/theme/app_colors.dart';

/// Replaces Arabic-Indic and Persian digits with Western (ASCII) 0–9.
String _westernDigits(String input) {
  return input.replaceAllMapped(RegExp(r'[\u0660-\u0669\u06F0-\u06F9]'), (m) {
    final c = m[0]!.codeUnitAt(0);
    if (c >= 0x0660 && c <= 0x0669) return '${c - 0x0660}';
    if (c >= 0x06F0 && c <= 0x06F9) return '${c - 0x06F0}';
    return m[0]!;
  });
}

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(appStateProvider).history;
    final theme = Theme.of(context);

    return ColoredBox(
      color: AppColors.bg,
      child: SafeArea(
        child: history.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 56,
                        color: AppColors.textSecondary.withValues(alpha: 0.45),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'no_history'.tr(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: history.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16, top: 4),
                      child: Text(
                        'trip_history_title'.tr(),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    );
                  }
                  final item = history[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _StyledTripCard(item: item),
                  );
                },
              ),
      ),
    );
  }
}

class _StyledTripCard extends StatelessWidget {
  const _StyledTripCard({required this.item});

  final TripRecord item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.locale.toString();
    final dateStr = _westernDigits(
      '${DateFormat.yMMMMd(locale).format(item.date)} • ${DateFormat.jm(locale).format(item.date)}',
    );
    final truckLabel =
        item.truckType == TruckType.singleCabine ? 'single_cabine'.tr() : 'double_cabine'.tr();
    final priceFormatted = item.cancelled
        ? '—'
        : '${NumberFormat.decimalPattern(context.locale.languageCode).format(item.price)} DA';
    final completed = !item.cancelled;

    final hasExtras = item.comment.isNotEmpty ||
        item.goodTraits.isNotEmpty ||
        item.badTraits.isNotEmpty;

    return Material(
      color: AppColors.card,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.textSecondary.withValues(alpha: 0.12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateStr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          truckLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        priceFormatted,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: item.cancelled
                              ? AppColors.textSecondary
                              : AppColors.brandOrange,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _StatusChip(completed: completed),
                    ],
                  ),
                ],
              ),
              if (item.cancelled && item.cancellationReason.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '${'cancellation_reason_label'.tr()}: ${item.cancellationReason}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.textSecondary.withValues(alpha: 0.12),
                ),
              ),
              _LocationRow(
                icon: Icons.place_outlined,
                iconColor: AppColors.textSecondary,
                text: item.pickup,
              ),
              const SizedBox(height: 12),
              _LocationRow(
                icon: Icons.navigation_rounded,
                iconColor: AppColors.brandOrange,
                text: item.dropoff,
              ),
              if (!item.cancelled && item.rating > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    ...List.generate(
                      5,
                      (i) => Icon(
                        i < item.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 18,
                        color: i < item.rating ? AppColors.brandOrange : AppColors.textSecondary.withValues(alpha: 0.35),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.rating}/5',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              if (hasExtras) ...[
                const SizedBox(height: 14),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.textSecondary.withValues(alpha: 0.08),
                ),
                const SizedBox(height: 12),
                if (item.comment.isNotEmpty)
                  Text(
                    item.comment,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                if (item.comment.isNotEmpty &&
                    (item.goodTraits.isNotEmpty || item.badTraits.isNotEmpty))
                  const SizedBox(height: 10),
                if (item.goodTraits.isNotEmpty || item.badTraits.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...item.goodTraits.map(
                        (t) => Chip(
                          label: Text(t, style: const TextStyle(fontSize: 11)),
                          backgroundColor: AppColors.success.withValues(alpha: 0.14),
                          side: BorderSide.none,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      ...item.badTraits.map(
                        (t) => Chip(
                          label: Text(t, style: const TextStyle(fontSize: 11)),
                          backgroundColor: Colors.red.shade50,
                          side: BorderSide(color: Colors.red.shade100),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
              ],
            ],
          ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    final label =
        completed ? 'trip_status_completed'.tr() : 'trip_status_cancelled'.tr();
    final bg = completed
        ? AppColors.success.withValues(alpha: 0.18)
        : Colors.red.shade50;
    final fg =
        completed ? AppColors.success : Colors.red.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
          ),
        ),
      ],
    );
  }
}
