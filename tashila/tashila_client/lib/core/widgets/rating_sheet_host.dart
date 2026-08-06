import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Redirects to the full screen driver rating flow page.
Future<void> showRequiredDriverRatingSheet(BuildContext context) async {
  context.go('/rate-driver');
}
