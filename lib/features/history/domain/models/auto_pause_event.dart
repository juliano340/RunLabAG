import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/utils/time_utils.dart';

class AutoPauseEvent {
  final double latitude;
  final double longitude;
  final int durationSeconds;
  final String timestamp;

  const AutoPauseEvent({
    required this.latitude,
    required this.longitude,
    required this.durationSeconds,
    required this.timestamp,
  });

  LatLng get location => LatLng(latitude, longitude);

  String get formattedDuration => TimeUtils.formatDuration(durationSeconds);

  Map<String, dynamic> toMap() {
    return {
      'lat': latitude,
      'lng': longitude,
      'durationSeconds': durationSeconds,
      'timestamp': timestamp,
    };
  }

  factory AutoPauseEvent.fromMap(Map<String, dynamic> map) {
    return AutoPauseEvent(
      latitude: (map['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['lng'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      timestamp: map['timestamp'] as String? ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AutoPauseEvent.fromJson(String source) =>
      AutoPauseEvent.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
