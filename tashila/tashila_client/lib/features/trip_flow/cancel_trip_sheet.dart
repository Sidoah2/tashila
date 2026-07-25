import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tashila_client/core/theme/app_colors.dart';

/// Stable API reason keys (see backend VALID_CANCEL_REASONS).
const _reasonKeys = [
  'changed_plans',
  'wrong_address',
  'found_alternative',
  'driver_too_long',
  'other',
];

/// Shows a bottom sheet to pick why the user cancels after a driver was found.
/// Returns a stable reason key for the API, or null if dismissed.
Future<String?> showCancelTripReasonSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _CancelTripReasonBody(),
  );
}

class _CancelTripReasonBody extends StatefulWidget {
  const _CancelTripReasonBody();

  @override
  State<_CancelTripReasonBody> createState() => _CancelTripReasonBodyState();
}

class _CancelTripReasonBodyState extends State<_CancelTripReasonBody> {
  String? _selectedKey;
  final _otherController = TextEditingController();

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_selectedKey == null) return false;
    if (_selectedKey == 'other') {
      return _otherController.text.trim().length >= 3;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'cancel_trip_title'.tr(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'cancel_trip_subtitle'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reasonKeys.map((key) {
                final selected = _selectedKey == key;
                return ChoiceChip(
                  label: Text('cancel_reason_$key'.tr()),
                  selected: selected,
                  selectedColor: AppColors.brandOrange.withValues(alpha: 0.22),
                  checkmarkColor: AppColors.brandOrange,
                  labelStyle: TextStyle(
                    color: selected ? AppColors.brandOrange : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  onSelected: (_) => setState(() => _selectedKey = key),
                );
              }).toList(),
            ),
            if (_selectedKey == 'other') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _otherController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'cancel_reason_other_hint'.tr(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('stay_with_trip'.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AppColors.brandOrange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.textSecondary.withValues(alpha: 0.28),
                    ),
                    onPressed: _canSubmit
                        ? () => Navigator.pop(context, _selectedKey)
                        : null,
                    child: Text('confirm_cancel_trip'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
