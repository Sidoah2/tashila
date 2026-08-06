import 'package:flutter/material.dart';
import 'package:tashila_client/features/trip_flow/driver_rating_sheet.dart';

/// Presents the post-trip driver rating flow as a mandatory, non-dismissible sheet.
Future<void> showRequiredDriverRatingSheet(BuildContext context) {
  return showModalBottomSheet<void>(
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
}
