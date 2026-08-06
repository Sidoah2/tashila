import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/upload_image_preview.dart';

Widget buildLocalProfileAvatarImpl({
  required String? path,
  required double radius,
  String? networkUrl,
  Color? placeholderColor,
}) {
  final color =
      placeholderColor ?? AppColors.textSecondary.withValues(alpha: 0.35);
  final local = path?.trim();
  if (local != null && local.isNotEmpty && !looksLikeRemoteImageUrl(local)) {
    final file = File(local);
    if (file.existsSync()) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(file),
      );
    }
  }

  final remote = networkUrl?.trim();
  if (remote != null &&
      remote.isNotEmpty &&
      looksLikeRemoteImageUrl(remote)) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: remote,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (_, __) => Icon(
            Icons.person,
            size: radius * 1.1,
            color: AppColors.textSecondary,
          ),
          errorWidget: (_, __, ___) => Icon(
            Icons.person,
            size: radius * 1.1,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  return CircleAvatar(
    radius: radius,
    backgroundColor: color,
    child: Icon(
      Icons.person,
      size: radius * 1.1,
      color: AppColors.textSecondary,
    ),
  );
}
