import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/app_colors.dart';

/// Circular countdown embedded in a trip-offer card (not a separate overlay).
class OfferCountdownRing extends StatelessWidget {
  const OfferCountdownRing({
    super.key,
    required this.offer,
    this.size = 72,
    this.strokeWidth = 5,
  });

  final IncomingOffer offer;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final seconds = offer.remainingSeconds;
    final ttl = offer.ttlSeconds;
    final progress = ttl > 0 ? seconds / ttl : 0.0;
    final urgent = seconds <= 8;
    final critical = seconds <= 3;

    final trackColor = Colors.black.withValues(alpha: 0.08);
    final progressColor = critical
        ? const Color(0xFFD32F2F)
        : urgent
            ? const Color(0xFFE65100)
            : AppColors.brandOrange;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress.clamp(0.0, 1.0),
              trackColor: trackColor,
              progressColor: progressColor,
              strokeWidth: strokeWidth,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$seconds',
                style: TextStyle(
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: critical
                      ? const Color(0xFFD32F2F)
                      : const Color(0xFF1A1A1A),
                ),
              ),
              Text(
                's',
                style: TextStyle(
                  fontSize: size * 0.14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final arc = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    final sweep = -math.pi * 2 * progress;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor;
  }
}
