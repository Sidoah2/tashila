import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tashila_driver/core/theme/app_colors.dart';

class ApiOverlayManager {
  static OverlayEntry? _overlayEntry;
  static CancelToken? _activeCancelToken;

  static void show(BuildContext context, {CancelToken? cancelToken}) {
    if (_overlayEntry != null) return;
    _activeCancelToken = cancelToken;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => ApiLoadingOverlay(
        onCancel: () {
          cancel();
          if (Navigator.of(ctx).canPop()) {
            Navigator.of(ctx).pop();
          }
        },
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
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
      color: Colors.black.withValues(alpha: 0.55),
      child: SafeArea(
        child: Stack(
          children: [
            // Close Button at top left or top right based on locale/layout
            Positioned(
              top: 16,
              left: isRtl ? null : 16,
              right: isRtl ? 16 : null,
              child: IconButton(
                onPressed: onCancel,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
            // Center animated Tashila brand text loader
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    TashilaTextLoader(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TashilaTextLoader extends StatefulWidget {
  const TashilaTextLoader({super.key});

  @override
  State<TashilaTextLoader> createState() => _TashilaTextLoaderState();
}

class _TashilaTextLoaderState extends State<TashilaTextLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  static const _letters = ['T', 'a', 's', 'h', 'i', 'l', 'a'];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value * _letters.length;

        return Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          children: List.generate(_letters.length, (index) {
            final letterProgress = (progress - index).clamp(0.0, 1.0);
            final opacity = letterProgress;
            final slideDirection = isRtl ? 15.0 : -15.0;
            final dx = (1.0 - letterProgress) * slideDirection;

            return Transform.translate(
              offset: Offset(dx, 0),
              child: Opacity(
                opacity: opacity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    _letters[index],
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: AppColors.brandOrange,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
