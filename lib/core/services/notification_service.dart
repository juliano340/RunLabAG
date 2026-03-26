import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('ic_stat_runlab');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  /// Send a milestone notification every time a km is completed.
  /// [km] = the km just completed, [pace] = formatted pace string.
  static Future<void> sendKmMilestone(int km, String pace) async {
    if (!_initialized) await initialize();

    // 1. Vibrate — respects device silent / vibrate mode
    final bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      // Pattern: short-long-short for a distinct "milestone" feel
      Vibration.vibrate(pattern: [0, 200, 100, 400]);
    }

    // 2. Push notification — shows in the notification tray even with screen off
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'km_milestone',           // channel id
      'Km Completado',          // channel name
      channelDescription: 'Notificação a cada km completado durante o treino',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,    // uses device vibration setting automatically
      playSound: true,
      icon: 'ic_stat_runlab',
      ticker: 'Km completado!',
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    final String emoji = _milestoneEmoji(km);

    await _plugin.show(
      id: km,
      title: '$emoji $km km concluído! 🏃',
      body: 'Ritmo: $pace/km  •  Continue assim!',
      notificationDetails: details,
    );
  }

  static String _milestoneEmoji(int km) {
    if (km == 1) return '🚦';
    if (km == 5) return '🏅';
    if (km == 10) return '🥇';
    if (km == 21) return '🏆';
    if (km == 42) return '🎖️';
    if (km % 5 == 0) return '⭐';
    return '✅';
  }
}
