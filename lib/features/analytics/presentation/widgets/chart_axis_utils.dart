/// Índices que devem receber rótulo no eixo X (no máximo [maxLabels]),
/// sempre incluindo o mais recente. Evita a faixa de números sobrepostos.
Set<int> pickLabelIndexes(int length, {int maxLabels = 5}) {
  if (length <= 0) return <int>{};
  if (length <= maxLabels) return {for (var i = 0; i < length; i++) i};

  final step = ((length - 1) / (maxLabels - 1)).ceil();
  final indexes = <int>{};
  for (var i = length - 1; i >= 0; i -= step) {
    indexes.add(i);
  }
  return indexes;
}

/// Intervalo "redondo" para o eixo Y (0,25 / 0,5 / 1 / 2 / 2,5 / 5 / 10 ...).
double niceStep(double span, {int targetSteps = 4}) {
  if (!span.isFinite || span <= 0) return 1;
  final rough = span / targetSteps;
  const candidates = [
    0.25, 0.5, 1.0, 2.0, 2.5, 5.0, 10.0, 20.0, 25.0, 50.0, 100.0, 250.0, 500.0,
  ];
  for (final candidate in candidates) {
    if (candidate >= rough) return candidate;
  }
  return candidates.last;
}

double niceCeil(double value, double step) => (value / step).ceil() * step;

double niceFloor(double value, double step) => (value / step).floor() * step;

/// Verdadeiro quando o valor do eixo caiu exatamente sobre um índice inteiro
/// (usado para ignorar os rótulos extras que o fl_chart gera nas bordas).
bool isIntegerTick(double value) => (value - value.roundToDouble()).abs() < 0.01;
