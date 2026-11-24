import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/notification_service.dart';
import '../domain/repositories/run_session_effects.dart';

class SystemRunSessionEffects implements RunSessionEffects {
  const SystemRunSessionEffects();

  @override
  Future<void> setWakeLock(bool enabled) async {
    if (enabled) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }

  @override
  Future<void> logRunStarted(String runType) {
    return AnalyticsService().logRunStarted(runType: runType);
  }

  @override
  Future<void> notifyKm(int km, String pace) {
    return NotificationService.sendKmMilestone(km, pace);
  }

  @override
  Future<void> autoPauseStarted() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      await Vibration.vibrate(duration: 350, amplitude: 180);
    } else {
      await HapticFeedback.heavyImpact();
    }
  }

  @override
  Future<void> autoPauseResumed() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      await Vibration.vibrate(pattern: [0, 120, 80, 120]);
    } else {
      await HapticFeedback.mediumImpact();
    }
  }

  @override
  Future<void> pacingStatusChanged() {
    return HapticFeedback.mediumImpact();
  }
}
