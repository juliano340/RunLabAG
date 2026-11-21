enum AlertType { plateau, performanceDrop, streakAtRisk }

enum AlertSeverity { info, warning, success }

class PerformanceAlert {
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String description;
  final String? suggestion;
  final DateTime detectedAt;

  PerformanceAlert({
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    this.suggestion,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();

  factory PerformanceAlert.plateau({
    required int weeks,
    required String suggestion,
  }) {
    return PerformanceAlert(
      type: AlertType.plateau,
      severity: AlertSeverity.warning,
      title: 'Platô detectado',
      description:
          'Seu pace estável há $weeks semanas. Varie os treinos para evoluir.',
      suggestion: suggestion,
    );
  }

  factory PerformanceAlert.drop({
    required int percentage,
    required String suggestion,
  }) {
    return PerformanceAlert(
      type: AlertType.performanceDrop,
      severity: AlertSeverity.warning,
      title: 'Queda de performance',
      description:
          'Pace piorou $percentage% comparado ao período anterior.',
      suggestion: suggestion,
    );
  }

  factory PerformanceAlert.streakAtRisk({
    required int currentStreak,
    required String suggestion,
  }) {
    return PerformanceAlert(
      type: AlertType.streakAtRisk,
      severity: AlertSeverity.info,
      title: 'Sequência em risco',
      description:
          'Seu streak de $currentStreak dias pode ser perdido se não treinar hoje.',
      suggestion: suggestion,
    );
  }
}
