import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tashila_client/core/theme/app_colors.dart';

class ApiOverlayManager {
  static OverlayEntry? _overlayEntry;
  static CancelToken? _activeCancelToken;

  static void show(BuildContext context, {CancelToken? cancelToken}) {
    if (_overlayEntry != null) return;
    _activeCancelToken = cancelToken;

    final overlayState = Overlay.maybeOf(context) ??
        Navigator.maybeOf(context, rootNavigator: true)?.overlay;

    if (overlayState == null) return;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => ApiLoadingOverlay(
        onCancel: () {
          cancel();
        },
      ),
    );

    overlayState.insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _activeCancelToken = null;
  }

  static void cancel() {
    if (_activeCancelToken != null && !_activeCancelToken!.isCancelled) {
      _activeCancelToken!.cancel('User cancelled request');
    }
    hide();
  }

  static bool get isShowing => _overlayEntry != null;
}

class ApiLoadingOverlay extends StatelessWidget {
  const ApiLoadingOverlay({super.key, required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Stack(
          children: [
            // Top Close Button (LTR left, RTL right)
            Positioned(
              top: 16,
              left: isRtl ? null : 16,
              right: isRtl ? 16 : null,
              child: IconButton(
                onPressed: onCancel,
                icon: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                ),
              ),
            ),
            // Center full-screen logo
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/arabic_logo.jpeg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.brandOrange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
