import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/driver_app_state.dart';

Future<void> confirmDriverLogout(BuildContext context, WidgetRef ref) async {
  final state = ref.read(driverAppStateProvider);
  if (state.hasActiveTrip) {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('logout_active_trip_title'.tr()),
        content: Text('logout_active_trip_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('profile_delete_account_cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('logout'.tr()),
          ),
        ],
      ),
    );
    if (proceed != true) return;
  }
  await ref.read(driverAppStateProvider.notifier).logout();
}
