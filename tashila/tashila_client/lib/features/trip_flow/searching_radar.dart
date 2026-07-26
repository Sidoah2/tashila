import 'package:flutter/material.dart';
import 'package:tashila_client/core/theme/app_colors.dart';

class SearchingRadarWidget extends StatefulWidget {
  const SearchingRadarWidget({super.key});

  @override
  State<SearchingRadarWidget> createState() => _SearchingRadarWidgetState();
}

class _SearchingRadarWidgetState extends State<SearchingRadarWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: SizedBox(
          width: 320,
          height: 320,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _RadarPainter(_controller.value),
                    size: const Size(320, 320),
                  );
                },
              ),
              // Center Pulse Pin or Icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.brandOrange,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandOrange.withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 3,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.brandOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // 3 concentric wave rings
    for (int i = 0; i < 3; i++) {
      final waveProgress = (progress + i / 3.0) % 1.0;
      final radius = maxRadius * waveProgress;
      final opacity = (1.0 - waveProgress) * 0.4;
      
      paint.color = AppColors.brandOrange.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
      
      // Draw a subtle filled inner layer as well
      final fillPaint = Paint()
        ..color = AppColors.brandOrange.withValues(alpha: opacity * 0.08)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
