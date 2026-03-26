import 'database_service.dart';

class RecommendationResult {
  final double recommendedGoal;
  final String message;
  final bool isIncrease;
  final String emoji;

  RecommendationResult({
    required this.recommendedGoal,
    required this.message,
    this.isIncrease = false,
    this.emoji = '💡',
  });
}

class RecommendationService {
  // ── Mood helpers ──────────────────────────────────────────────────────────
  static int _moodScore(String mood) {
    const positive = ['😁', '😊', '💪', '🔥', '⚡'];
    const negative = ['😓', '😩', '🤕', '😞', '😴', '🥵'];
    if (positive.any((e) => mood.contains(e))) return 1;
    if (negative.any((e) => mood.contains(e))) return -1;
    return 0;
  }

  // ── Activity-type helpers ────────────────────────────────────────────────
  static bool _isRun(RunModel r) {
    final t = r.type.toLowerCase();
    return t.contains('corr') || t.contains('run') || t.isEmpty;
  }

  // ── Avg pace in sec/km ───────────────────────────────────────────────────
  static double _avgPaceSeconds(List<RunModel> runs) {
    final running = runs.where(_isRun).toList();
    if (running.isEmpty) return 0;
    int totalSec = running.fold(0, (s, r) => s + r.durationSeconds);
    double totalKm = running.fold(0.0, (s, r) => s + r.distanceKm);
    return totalKm > 0 ? totalSec / totalKm : 0;
  }

  // ── Main entry point ─────────────────────────────────────────────────────
  /// [currentWeekRuns]  – runs that belong to the currently displayed week.
  /// [monthRuns]        – runs of the last ~30 days (for pace-trend analysis).
  /// [currentPeriodGoal] – the historically-frozen goal for this week.
  static RecommendationResult calculateWeeklyRecommendation({
    required UserProfile profile,
    required List<RunModel>
    runs, // kept for backward compat — treated as currentWeekRuns
    List<RunModel> monthRuns = const [],
    double? currentPeriodGoal,
  }) {
    final List<RunModel> currentWeekRuns = runs;
    final double goalKm = currentPeriodGoal ?? profile.weeklyGoal;
    final now = DateTime.now();
    final weekday = now.weekday; // Mon=1 … Sun=7

    // ── 1. Base metrics ──────────────────────────────────────────────────
    double weekKm = currentWeekRuns.fold(0.0, (s, r) => s + r.distanceKm);
    Set<String> activeDates = {
      for (var r in currentWeekRuns) r.date.toIso8601String().split('T')[0],
    };
    int activeDays = activeDates.length;
    double achievementRatio = goalKm > 0 ? weekKm / goalKm : 0.0;

    // ── 2. Mood analysis ─────────────────────────────────────────────────
    int moodSum = currentWeekRuns.fold(0, (s, r) => s + _moodScore(r.mood));
    int moodSignal = moodSum > 0 ? 1 : (moodSum < 0 ? -1 : 0);

    // ── 3. Activity-type split ───────────────────────────────────────────
    double runKm = currentWeekRuns
        .where(_isRun)
        .fold(0.0, (s, r) => s + r.distanceKm);
    double walkKm = weekKm - runKm;
    bool dominatedByWalking = weekKm > 0 && walkKm > runKm;

    // ── 4. Pace trend vs monthly baseline ────────────────────────────────
    double weekPace = _avgPaceSeconds(currentWeekRuns);
    final startOfWeek = now.subtract(Duration(days: weekday - 1));
    final monthBaseline = monthRuns
        .where((r) => r.date.isBefore(startOfWeek))
        .toList();
    double monthPace = _avgPaceSeconds(monthBaseline);
    bool muchSlower =
        monthPace > 0 &&
        weekPace > 0 &&
        (weekPace - monthPace) / monthPace > 0.15;

    // ── 5. Cooldown gate ─────────────────────────────────────────────────
    if (profile.lastGoalUpdate != null) {
      final daysSinceUpdate = now.difference(profile.lastGoalUpdate!).inDays;
      if (daysSinceUpdate < 7) {
        return RecommendationResult(
          recommendedGoal: goalKm,
          emoji: '⏱️',
          message:
              'Meta atualizada há menos de 7 dias. Mantenha os '
              '${goalKm.toStringAsFixed(1)} km por esta semana para consolidar o ritmo.',
          isIncrease: false,
        );
      }
    }

    // ── 6. Anti-injury override ───────────────────────────────────────────
    if (moodSignal < 0 || muchSlower) {
      String reason = moodSignal < 0
          ? 'Seus registros desta semana indicam cansaço ou desconforto físico.'
          : 'Seu pace esta semana está mais de 15% mais lento que o histórico recente.';
      double safeGoal = achievementRatio < 0.5
          ? (goalKm * 0.9 * 2).roundToDouble() / 2
          : goalKm;
      return RecommendationResult(
        recommendedGoal: safeGoal,
        emoji: '🔴',
        message:
            '$reason Priorize recuperação. '
            '${safeGoal < goalKm ? "Sugerimos reduzir para ${safeGoal.toStringAsFixed(1)} km na próxima semana." : "Mantenha os ${goalKm.toStringAsFixed(1)} km."}',
        isIncrease: false,
      );
    }

    // ── 7. Early-week informational card (Mon-Fri) ─────────────────────────
    if (weekday < 6) {
      double pct = (achievementRatio * 100).clamp(0, 100);
      String verb = pct >= 50
          ? 'Ótimo começo de semana'
          : 'Semana em andamento';
      return RecommendationResult(
        recommendedGoal: goalKm,
        emoji: '📊',
        message:
            '$verb! ${weekKm.toStringAsFixed(1)} km percorridos '
            '(${pct.toStringAsFixed(0)}% de ${goalKm.toStringAsFixed(1)} km). '
            'Sugestões de meta aparecerão a partir de sábado.',
        isIncrease: false,
      );
    }

    // ── 8. Weekend progressive recommendation (Sat/Sun) ───────────────────
    if (achievementRatio >= 0.9) {
      double inc;
      String consistency;

      if (dominatedByWalking) {
        inc = 0.05;
        consistency =
            'Caminhadas dominam — ótimo para a base aeróbica, avance com cautela.';
      } else if (activeDays >= 4) {
        inc = 0.10;
        consistency = 'Excelente frequência ($activeDays dias ativos)!';
      } else if (activeDays >= 3) {
        inc = 0.07;
        consistency = 'Boa consistência com $activeDays dias.';
      } else {
        inc = 0.05;
        consistency =
            'Meta batida! Aumento conservador para proteger as articulações.';
      }
      if (moodSignal > 0) inc += 0.02; // bonus for positive mood

      double nextGoal = (weekKm * (1 + inc) * 2).roundToDouble() / 2;
      return RecommendationResult(
        recommendedGoal: nextGoal,
        emoji: '🚀',
        message:
            '$consistency Sugerimos ${nextGoal.toStringAsFixed(1)} km para a próxima semana '
            '(+${(inc * 100).toStringAsFixed(0)}%).',
        isIncrease: true,
      );
    }

    if (achievementRatio < 0.5 && weekKm > 0) {
      double nextGoal = (goalKm * 0.9 * 2).roundToDouble() / 2;
      return RecommendationResult(
        recommendedGoal: nextGoal,
        emoji: '🟡',
        message:
            'Semana desafiadora (${weekKm.toStringAsFixed(1)} km de ${goalKm.toStringAsFixed(1)} km). '
            'Que tal ajustar para ${nextGoal.toStringAsFixed(1)} km e retomar o fôlego?',
        isIncrease: false,
      );
    }

    // Default: maintain
    return RecommendationResult(
      recommendedGoal: goalKm,
      emoji: '💪',
      message:
          'Você está no caminho certo! Mantenha os ${goalKm.toStringAsFixed(1)} km '
          'por mais uma semana para solidificar a evolução.',
      isIncrease: false,
    );
  }
}
