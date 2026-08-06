import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

bool looksLikeRemoteImageUrl(String? value) {
  if (value == null || value.isEmpty) return false;
  final v = value.trim();
  return v.startsWith('http://') ||
      v.startsWith('https://') ||
      v.startsWith('//');
}

/// Shows a local file preview when available, otherwise loads [remoteUrl].
class UploadImagePreview extends StatelessWidget {
  const UploadImagePreview({
    super.key,
    this.localPath,
    this.remoteUrl,
    this.width = 56,
    this.height = 56,
    this.borderRadius = 8,
    this.placeholder,
  });

  final String? localPath;
  final String? remoteUrl;
  final double width;
  final double height;
  final double borderRadius;
  final Widget? placeholder;

  Widget _fallback() {
    return placeholder ??
        Icon(
          Icons.person_outline,
          color: AppColors.textSecondary.withValues(alpha: 0.7),
        );
  }

  @override
  Widget build(BuildContext context) {
    final local = localPath?.trim();
    if (local != null && local.isNotEmpty && !looksLikeRemoteImageUrl(local)) {
      final file = File(local);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.file(
            file,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _boxed(_fallback()),
          ),
        );
      }
    }

    final remote = remoteUrl?.trim();
    if (remote != null && remote.isNotEmpty && looksLikeRemoteImageUrl(remote)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CachedNetworkImage(
          imageUrl: remote,
          width: width,
          height: height,
          fit: BoxFit.cover,
          placeholder: (_, __) => _boxed(
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.brandOrange,
              ),
            ),
          ),
          errorWidget: (_, __, ___) => _boxed(_fallback()),
        ),
      );
    }

    return _boxed(_fallback());
  }

  Widget _boxed(Widget child) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.15),
        ),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
