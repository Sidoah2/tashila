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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                itemCount: history.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16, top: 4),
                      child: Text(
                        'trip_history_title'.tr(),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.04),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      padding: const EdgeInsets.all(18),
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
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      truckLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.2,
                        fontSize: 15,
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
                      fontWeight: FontWeight.w900,
                      color: item.cancelled ? AppColors.textSecondary : AppColors.brandOrange,
                      height: 1.1,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _StatusChip(completed: completed),
                ],
              ),
            ],
          ),
          if (item.cancelled && item.cancellationReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${'cancellation_reason_label'.tr()}: ${item.cancellationReason}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.red.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          // Unified vertical location timeline connector
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 4),
                    const Icon(Icons.circle, size: 8, color: Colors.green),
                    Container(
                      width: 1.5,
                      height: 28,
                      color: Colors.grey.shade200,
                    ),
                    const Icon(Icons.stop, size: 8, color: AppColors.brandOrange),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.pickup,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        item.dropoff,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!item.cancelled && item.rating > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade100, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: i < item.rating ? Colors.amber.shade700 : Colors.amber.shade200,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${item.rating}/5',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
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
                  fontWeight: FontWeight.w500,
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
                      label: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      backgroundColor: AppColors.success.withValues(alpha: 0.12),
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  ...item.badTraits.map(
                    (t) => Chip(
                      label: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      backgroundColor: Colors.red.shade50,
                      side: BorderSide(color: Colors.red.shade100, width: 0.5),
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


