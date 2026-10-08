import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../theme/app_colors.dart';

/// Resolves an avatar URL, supporting absolute URLs, protocol-relative URLs,
/// and relative server endpoints by prepending [kApiBaseUrl].
String? resolveAvatarUrl(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  if (trimmed.startsWith('//')) {
    return 'https:$trimmed';
  }
  final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
  return '$kApiBaseUrl$path';
}

/// A circular avatar widget for displaying client profile pictures in the driver app.
class ClientAvatar extends StatelessWidget {
  const ClientAvatar({
    super.key,
    required this.avatarUrl,
    this.radius = 26,
    this.iconSize = 28,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.5,
  });

  final String? avatarUrl;
  final double radius;
  final double iconSize;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = resolveAvatarUrl(avatarUrl);
    final bg =
        backgroundColor ?? AppColors.brandOrange.withValues(alpha: 0.12);
    final border =
        borderColor ?? AppColors.brandOrange.withValues(alpha: 0.3);

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: borderWidth > 0
            ? Border.all(color: border, width: borderWidth)
            : null,
      ),
      child: ClipOval(
        child: resolvedUrl != null
            ? CachedNetworkImage(
                imageUrl: resolvedUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(
                  child: SizedBox(
                    width: radius * 0.75,
                    height: radius * 0.75,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brandOrange,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Icon(
                  Icons.person_rounded,
                  color: AppColors.brandOrange,
                  size: iconSize,
                ),
              )
            : Icon(
                Icons.person_rounded,
                color: AppColors.brandOrange,
                size: iconSize,
              ),
      ),
    );
  }
}
