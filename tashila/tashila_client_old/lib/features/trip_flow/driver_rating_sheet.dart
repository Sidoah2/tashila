import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tashila_client/core/formatting/app_format.dart';
import 'package:tashila_client/core/state/app_state.dart';
import 'package:tashila_client/core/theme/app_colors.dart';
import 'package:tashila_client/core/widgets/primary_button.dart';

/// i18n keys only (without prefix).
const _goodTraitKeys = [
  'trait_good_punctual',
  'trait_good_polite',
  'trait_good_careful_handling',
  'trait_good_clean_vehicle',
  'trait_good_smooth_ride',
];

const _badTraitKeys = [
  'trait_bad_late',
  'trait_bad_rude',
  'trait_bad_rough_driving',
  'trait_bad_dirty_vehicle',
  'trait_bad_wrong_route',
];

/// Post-trip rating: stars + good/bad trait chips + optional comment + price.
class DriverRatingSheetContent extends ConsumerStatefulWidget {
  const DriverRatingSheetContent({super.key});

  @override
  ConsumerState<DriverRatingSheetContent> createState() =>
      _DriverRatingSheetContentState();
}

class _DriverRatingSheetContentState extends ConsumerState<DriverRatingSheetContent> {
  int _stars = 0;
  final _comment = TextEditingController();
  final Set<String> _goodSelected = {};
  final Set<String> _badSelected = {};
  bool _submitting = false;
  bool _submitted = false;

  double get _tripPrice {
    final state = ref.read(appStateProvider);
    return state.estimatedPrice > 0 ? state.estimatedPrice : kEstimatedTripPrice;
  }

  bool get _canSubmit => _stars >= 1 && !_submitting;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    final ok = await ref.read(appStateProvider.notifier).submitRating(
          stars: _stars,
          comment: _comment.text.trim(),
          goodTraits: _goodSelected.map((k) => k.tr()).toList(),
          badTraits: _badSelected.map((k) => k.tr()).toList(),
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (ok) _submitted = true;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('rating_submit_failed'.tr())),
      );
    }
  }

  Future<void> _finish() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await ref.read(appStateProvider.notifier).completeRatingSession();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceStr = formatTripPrice(_tripPrice);

    if (_submitted) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Icon(Icons.check_circle_rounded, size: 56, color: AppColors.success),
            const SizedBox(height: 12),
            Text(
              'rating_submitted_title'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'rating_submitted_message'.tr(namedArgs: {'amount': priceStr}),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.brandOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.brandOrange.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'trip_summary_price_label'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    priceStr,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.brandOrange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'rating_done_button'.tr(),
              onPressed: _submitting ? null : _finish,
              icon: Icons.done_rounded,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Icon(Icons.star_rounded, size: 36, color: AppColors.brandOrange),
            const SizedBox(height: 8),
            Text(
              'rate_driver'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.brandOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.brandOrange.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: AppColors.brandOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'rating_required_notice'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.brandOrange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'rating_trip_price_label'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    priceStr,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.brandOrange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final n = index + 1;
                final filled = n <= _stars;
                return IconButton(
                  onPressed: () => setState(() => _stars = n),
                  iconSize: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  icon: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: filled ? AppColors.brandOrange : AppColors.textSecondary,
                  ),
                );
              }),
            ),
            Text(
              _stars == 0
                  ? 'rating_select_stars'.tr()
                  : ltrNumber('$_stars/5'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: _stars == 0 ? AppColors.textSecondary : AppColors.brandOrange,
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'rating_good_traits'.tr(),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _goodTraitKeys.map((key) {
                final selected = _goodSelected.contains(key);
                return FilterChip(
                  label: Text(key.tr()),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _goodSelected.add(key);
                    } else {
                      _goodSelected.remove(key);
                    }
                  }),
                  selectedColor: AppColors.success.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.success,
                  labelStyle: TextStyle(
                    color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'rating_bad_traits'.tr(),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _badTraitKeys.map((key) {
                final selected = _badSelected.contains(key);
                return FilterChip(
                  label: Text(key.tr()),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _badSelected.add(key);
                    } else {
                      _badSelected.remove(key);
                    }
                  }),
                  selectedColor: Colors.red.shade50,
                  checkmarkColor: Colors.red.shade700,
                  side: BorderSide(
                    color: selected ? Colors.red.shade300 : AppColors.textSecondary.withValues(alpha: 0.35),
                  ),
                  labelStyle: TextStyle(
                    color: selected ? Colors.red.shade900 : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _comment,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'optional_comment'.tr(),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: _stars == 0 ? 'rating_stars_required'.tr() : 'submit'.tr(),
              onPressed: _canSubmit ? _submit : null,
              icon: Icons.send_outlined,
            ),
          ],
        ),
      ),
    );
  }
}
