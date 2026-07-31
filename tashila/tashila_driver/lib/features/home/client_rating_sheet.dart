import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/app_format.dart';
import '../../core/state/driver_app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/primary_button.dart';

const _goodTraitKeys = [
  'trait_good_punctual',
  'trait_good_polite',
  'trait_good_clear_communication',
  'trait_good_pickup_ready',
  'trait_good_cooperative',
];

const _badTraitKeys = [
  'trait_bad_late',
  'trait_bad_rude',
  'trait_bad_wrong_pin',
  'trait_bad_no_show',
  'trait_bad_payment_delay',
];

class ClientRatingSheetContent extends ConsumerStatefulWidget {
  const ClientRatingSheetContent({super.key});

  @override
  ConsumerState<ClientRatingSheetContent> createState() =>
      _ClientRatingSheetContentState();
}

class _ClientRatingSheetContentState
    extends ConsumerState<ClientRatingSheetContent> {
  int _stars = 0;
  final _comment = TextEditingController();
  final Set<String> _goodSelected = {};
  final Set<String> _badSelected = {};
  bool _submitting = false;
  bool _submitted = false;

  bool get _canSubmit => _stars >= 1 && !_submitting;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    final ok = await ref
        .read(driverAppStateProvider.notifier)
        .submitClientRating(
          rating: _stars,
          comment: _comment.text.trim(),
          goodTraits: _goodSelected.map((k) => k.tr()).toList(),
          badTraits: _badSelected.map((k) => k.tr()).toList(),
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (ok) _submitted = true;
    });
    if (ok) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _finish();
        }
      });
    }
    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('rating_submit_failed'.tr())));
    }
  }

  Future<void> _finish() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await ref
        .read(driverAppStateProvider.notifier)
        .completeClientRatingSession();
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fare = ref.watch(driverAppStateProvider).currentRequest?.fare ?? 0;
    final fareStr = formatTripPrice(fare);

    if (_submitted) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 56,
              color: AppColors.success,
            ),
            const SizedBox(height: 14),
            Text(
              'rating_submitted_title'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'driver_rating_submitted_message'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            if (fare > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brandOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.brandOrange.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'trip_fare_label'.tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      fareStr,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppColors.brandOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'rating_done_button'.tr(),
              onPressed: _submitting ? null : _finish,
              icon: Icons.done_rounded,
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 620),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Orange Star Icon
            const Center(
              child: Icon(
                Icons.star_rounded,
                size: 38,
                color: AppColors.brandOrange,
              ),
            ),
            const SizedBox(height: 6),

            // Title
            Text(
              'rate_client'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Orange Callout Notice Container (Matching Screenshot)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.brandOrange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.brandOrange,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'rating_required_notice'.tr(),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 5-Star Selection Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final n = index + 1;
                final filled = n <= _stars;
                return IconButton(
                  onPressed: () => setState(() => _stars = n),
                  iconSize: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  icon: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: filled
                        ? AppColors.brandOrange
                        : Colors.grey.shade400,
                  ),
                );
              }),
            ),

            Text(
              _stars == 0 ? 'rating_select_stars'.tr() : ltrNumber('$_stars/5'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _stars == 0
                    ? AppColors.textSecondary
                    : AppColors.brandOrange,
              ),
            ),
            const SizedBox(height: 20),

            // "What went well" Section Header
            Text(
              'rating_good_traits'.tr(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _goodTraitKeys.map((key) {
                final selected = _goodSelected.contains(key);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _goodSelected.remove(key);
                    } else {
                      _goodSelected.add(key);
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.brandOrange.withValues(alpha: 0.12)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppColors.brandOrange
                            : Colors.black.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      key.tr(),
                      style: TextStyle(
                        color: selected
                            ? AppColors.brandOrange
                            : Colors.black87,
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // "Could improve" Section Header
            Text(
              'rating_bad_traits'.tr(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _badTraitKeys.map((key) {
                final selected = _badSelected.contains(key);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _badSelected.remove(key);
                    } else {
                      _badSelected.add(key);
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? Colors.red.shade50 : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? Colors.red.shade300
                            : Colors.black.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      key.tr(),
                      style: TextStyle(
                        color: selected ? Colors.red.shade800 : Colors.black87,
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Optional Comment TextField
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _comment,
                maxLines: 3,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'optional_comment'.tr(),
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Primary Submit Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _stars == 0 ? 'rating_stars_required'.tr() : 'submit'.tr(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
