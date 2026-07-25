import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

Widget buildLocalProfileAvatarImpl({
  required String? path,
  required double radius,
  String? networkUrl,
  Color? placeholderColor,
}) {
  final color = placeholderColor ?? AppColors.textSecondary.withValues(alpha: 0.35);
  return CircleAvatar(
    radius: radius,
    backgroundColor: color,
    child: Icon(Icons.person, size: radius * 1.1, color: AppColors.textSecondary),
  );
}
