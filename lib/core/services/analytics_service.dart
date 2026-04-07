import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Centraliza todos os eventos de analytics e o reporting de crashes.
///
/// Design defensivo: todos os métodos têm try/catch e nunca lançam exceção.
/// Se o Firebase não estiver configurado (sem google-services.json), o app
/// continua funcionando normalmente — apenas sem telemetria.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Inicializa o Firebase de forma segura.
  /// Deve ser chamado uma única vez em main() antes de qualquer outro método.
  Future<void> init() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      // Crashlytics: captura erros Flutter não tratados
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;

      // Crashlytics: captura erros assíncronos fora do framework
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      _isInitialized = true;
      debugPrint('[Analytics] Firebase inicializado com sucesso.');
    } catch (e) {
      // Falha silenciosa — app continua sem analytics
      // Causa mais comum: google-services.json ausente em android/app/
      debugPrint('[Analytics] Firebase não disponível (sem google-services.json?): $e');
    }
  }

  // ──────────────────────────────────────────────
  // Corridas
  // ──────────────────────────────────────────────

  Future<void> logRunStarted({required String runType}) async {
    if (!_isInitialized) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'run_started',
        parameters: {'run_type': runType},
      );
    } catch (e) {
      debugPrint('[Analytics] logRunStarted error: $e');
    }
  }

  Future<void> logRunCompleted({
    required double distanceKm,
    required int durationSeconds,
    required String pace,
    required int calories,
    required String runType,
    required String mood,
  }) async {
    if (!_isInitialized) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'run_completed',
        parameters: {
          'distance_km': distanceKm,
          'duration_seconds': durationSeconds,
          'pace': pace,
          'calories': calories,
          'run_type': runType,
          'mood': mood,
        },
      );
    } catch (e) {
      debugPrint('[Analytics] logRunCompleted error: $e');
    }
  }

  Future<void> logRunDiscarded({required double distanceKm}) async {
    if (!_isInitialized) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'run_discarded',
        parameters: {'distance_km': distanceKm},
      );
    } catch (e) {
      debugPrint('[Analytics] logRunDiscarded error: $e');
    }
  }

  // ──────────────────────────────────────────────
  // Compartilhamento
  // ──────────────────────────────────────────────

  Future<void> logShareCreated({required String template}) async {
    if (!_isInitialized) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'share_created',
        parameters: {'template': template},
      );
    } catch (e) {
      debugPrint('[Analytics] logShareCreated error: $e');
    }
  }

  Future<void> logPremiumTemplateUnlocked({required String template}) async {
    if (!_isInitialized) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'premium_template_unlocked',
        parameters: {'template': template},
      );
    } catch (e) {
      debugPrint('[Analytics] logPremiumTemplateUnlocked error: $e');
    }
  }

  // ──────────────────────────────────────────────
  // Conquistas
  // ──────────────────────────────────────────────

  Future<void> logAchievementUnlocked({required String achievementId}) async {
    if (!_isInitialized) return;
    try {
      await FirebaseAnalytics.instance.logUnlockAchievement(id: achievementId);
    } catch (e) {
      debugPrint('[Analytics] logAchievementUnlocked error: $e');
    }
  }

  // ──────────────────────────────────────────────
  // Anúncios
  // ──────────────────────────────────────────────

  Future<void> logInterstitialShown() async {
    if (!_isInitialized) return;
    try {
      await FirebaseAnalytics.instance.logEvent(name: 'ad_interstitial_shown');
    } catch (e) {
      debugPrint('[Analytics] logInterstitialShown error: $e');
    }
  }

  Future<void> logRewardedAdShown({required String placement}) async {
    if (!_isInitialized) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'ad_rewarded_shown',
        parameters: {'placement': placement},
      );
    } catch (e) {
      debugPrint('[Analytics] logRewardedAdShown error: $e');
    }
  }

  // ──────────────────────────────────────────────
  // Crashlytics / identificação
  // ──────────────────────────────────────────────

  Future<void> setUserId(String userId) async {
    if (!_isInitialized) return;
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(userId);
      await FirebaseAnalytics.instance.setUserId(id: userId);
    } catch (e) {
      debugPrint('[Analytics] setUserId error: $e');
    }
  }

  Future<void> setCustomKey(String key, String value) async {
    if (!_isInitialized) return;
    try {
      await FirebaseCrashlytics.instance.setCustomKey(key, value);
    } catch (e) {
      debugPrint('[Analytics] setCustomKey error: $e');
    }
  }

  Future<void> recordError(dynamic exception, StackTrace? stack,
      {String? reason}) async {
    if (!_isInitialized) return;
    try {
      await FirebaseCrashlytics.instance.recordError(
        exception,
        stack,
        reason: reason,
        fatal: false,
      );
    } catch (e) {
      debugPrint('[Analytics] recordError error: $e');
    }
  }
}
