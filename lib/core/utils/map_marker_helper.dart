import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapMarkerHelper {
  /// Generates a premium custom pause marker (orange circle with a pause icon)
  static Future<BitmapDescriptor> getPauseMarkerIcon({
    double radius = 16.0,
    double shadowRadius = 3.0,
    double borderWidth = 2.0,
  }) async {
    return _drawMarker(
      circleColor: const Color(0xFFFF9800), // Elegant orange
      iconColor: Colors.white,
      radius: radius,
      shadowRadius: shadowRadius,
      borderWidth: borderWidth,
      isPause: true,
    );
  }

  /// Generates a premium custom resume marker (green circle with a play icon)
  static Future<BitmapDescriptor> getResumeMarkerIcon({
    double radius = 16.0,
    double shadowRadius = 3.0,
    double borderWidth = 2.0,
  }) async {
    return _drawMarker(
      circleColor: const Color(0xFF10B981), // Elegant emerald green
      iconColor: Colors.white,
      radius: radius,
      shadowRadius: shadowRadius,
      borderWidth: borderWidth,
      isPause: false,
    );
  }

  static Future<BitmapDescriptor> _drawMarker({
    required Color circleColor,
    required Color iconColor,
    required double radius,
    required double shadowRadius,
    required double borderWidth,
    required bool isPause,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    
    // Total diameter including shadow padding
    final double size = (radius + shadowRadius) * 2;

    // 1. Draw Shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowRadius);
    canvas.drawCircle(Offset(size / 2, size / 2 + 1.0), radius, shadowPaint);

    // 2. Draw White Border Ring
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), radius, borderPaint);

    // 3. Draw Inner Main Circle
    final Paint circlePaint = Paint()
      ..color = circleColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), radius - borderWidth, circlePaint);

    // 4. Draw Vector Icon
    final Paint iconPaint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.fill;

    if (isPause) {
      // Draw Pause Icon: 2 vertical bars
      final double barWidth = radius * 0.16;
      final double barHeight = radius * 0.42;
      final double gap = radius * 0.12;

      // Left bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size / 2 - gap / 2 - barWidth,
            size / 2 - barHeight / 2,
            barWidth,
            barHeight,
          ),
          Radius.circular(radius * 0.05),
        ),
        iconPaint,
      );

      // Right bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size / 2 + gap / 2,
            size / 2 - barHeight / 2,
            barWidth,
            barHeight,
          ),
          Radius.circular(radius * 0.05),
        ),
        iconPaint,
      );
    } else {
      // Draw Play/Resume Icon: triangle pointing right
      final double playSize = radius * 0.44;
      final double halfHeight = playSize / 2;
      // Optical adjustment: shift triangle slightly right
      final double xOffset = playSize * 0.10;

      final Path playPath = Path()
        ..moveTo(size / 2 - playSize / 3 + xOffset, size / 2 - halfHeight)
        ..lineTo(size / 2 + playSize * 2 / 3 + xOffset, size / 2)
        ..lineTo(size / 2 - playSize / 3 + xOffset, size / 2 + halfHeight)
        ..close();

      canvas.drawPath(playPath, iconPaint);
    }

    // Convert canvas to image bytes
    final ui.Image image = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }
}
