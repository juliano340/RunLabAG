import 'package:flutter/material.dart';

class ActiveRunGoalRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  ActiveRunGoalRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      3.14159 * 2 * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(ActiveRunGoalRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
