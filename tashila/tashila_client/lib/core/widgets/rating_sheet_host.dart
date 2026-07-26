import 'package:flutter/material.dart';
import 'package:tashila_client/features/trip_flow/driver_rating_sheet.dart';

bool _isRatingSheetShowing = false;

/// Presents the post-trip driver rating flow as a mandatory, non-dismissible sheet.
Future<void> showRequiredDriverRatingSheet(BuildContext context) async {
  if (_isRatingSheetShowing) return;
  _isRatingSheetShowing = true;
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: const DriverRatingSheetContent(),
          ),
        );
      },
    );
  } finally {
    _isRatingSheetShowing = false;
  }
}
