import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../domain/models/monthly_evolution_stats.dart';

const _monthShort = [
  'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
  'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
];

/// Comparativo mês a mês: escolhe um mês em cima, outro embaixo, e vê a
/// diferença em gráfico de barras duplas (distância, treinos, calorias,
/// pace). Os meses vêm do histórico carregado (até 36 meses).
///
/// A seleção guarda o periodId (não a identidade do objeto): após hot
/// reload a lista é reconstruída e a escolha continua valendo.
class PeriodComparisonSection extends StatefulWidget {
  const PeriodComparisonSection({super.key, required this.monthlyData});

  /// Meses do mais recente para o mais antigo (ordem do banco).
  final List<MonthlyEvolutionStats> monthlyData;

  @override
  State<PeriodComparisonSection> createState() =>
      _PeriodComparisonSectionState();
}

class _PeriodComparisonSectionState extends State<PeriodComparisonSection> {
  String? _periodIdA;
  String? _periodIdB;

  List<MonthlyEvolutionStats> get _months => widget.monthlyData;

  MonthlyEvolutionStats? _byId(String? id) {
    if (id == null) return null;
    for (final m in _months) {
      if (m.periodId == id) return m;
    }
    return null;
  }

  String _label(MonthlyEvolutionStats? m) {
    if (m == null) return '--';
    return '${_monthShort[m.startDate.month - 1]}'
        '/${(m.startDate.year % 100).toString().padLeft(2, '0')}';
  }

  double _paceMinPerKm(MonthlyEvolutionStats m) {
    return m.totalDistance > 0
        ? (m.totalDurationSeconds / 60) / m.totalDistance
        : 0;
  }

  String _paceLabel(MonthlyEvolutionStats m) {
    final pace = _paceMinPerKm(m);
    if (pace <= 0) return '--:--/km';
    final total = (pace * 60).round();
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}/km';
  }

  @override
  void initState() {
    super.initState();
    final months = widget.monthlyData;
    if (months.isNotEmpty) {
      // A = mês mais recente; B = mês mais recente COM treinos, para a
      // comparação inicial fazer sentido.
      _periodIdA = months.first.periodId;
      for (final m in months.skip(1)) {
        if (m.runCount > 0) {
          _periodIdB = m.periodId;
          break;
        }
      }
      _periodIdB ??= months.length > 1
          ? months[1].periodId
          : months.first.periodId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.textMuted : AppColors.textMutedDark;
    final accent = isDark ? AppColors.primaryNeon : AppColors.lightPrimary;
    final textColor = isDark ? AppColors.textLight : AppColors.textDark;

    final a = _byId(_periodIdA);
    final b = _byId(_periodIdB);

    if (_months.isEmpty || a == null || b == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comparativo',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sem dados suficientes para comparar — registre treinos em pelo '
            'menos dois meses.',
            style: GoogleFonts.outfit(fontSize: 11, color: muted),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comparativo',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),
        // Seletores: um mês em cima, outro embaixo
        Row(
          children: [
            Expanded(
              child: _monthDropdown(
                selected: a,
                color: accent,
                isDark: isDark,
                onChanged: (m) => setState(() => _periodIdA = m?.periodId),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'vs',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ),
            Expanded(
              child: _monthDropdown(
                selected: b,
                color: muted,
                isDark: isDark,
                onChanged: (m) {
                  if (m == null) return;
                  setState(() {
                    if (m.periodId == _periodIdA) {
                      // Escolheu o mês do topo no dropdown de baixo: troca.
                      _periodIdB = _periodIdA;
                      _periodIdA = m.periodId;
                    } else {
                      _periodIdB = m.periodId;
                    }
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GlassContainer(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
          child: Column(
            children: [
              _metric(
                label: 'Distância',
                valueA: '${a.totalDistance.toStringAsFixed(1)} km',
                valueB: '${b.totalDistance.toStringAsFixed(1)} km',
                a: a.totalDistance,
                b: b.totalDistance,
                labelA: _label(a),
                labelB: _label(b),
                accent: accent,
                muted: muted,
                textColor: textColor,
                isDark: isDark,
              ),
              const SizedBox(height: 14),
              _metric(
                label: 'Treinos',
                valueA: '${a.runCount}',
                valueB: '${b.runCount}',
                a: a.runCount.toDouble(),
                b: b.runCount.toDouble(),
                labelA: _label(a),
                labelB: _label(b),
                accent: accent,
                muted: muted,
                textColor: textColor,
                isDark: isDark,
              ),
              const SizedBox(height: 14),
              _metric(
                label: 'Calorias',
                valueA: '${a.totalCalories} kcal',
                valueB: '${b.totalCalories} kcal',
                a: a.totalCalories.toDouble(),
                b: b.totalCalories.toDouble(),
                labelA: _label(a),
                labelB: _label(b),
                accent: accent,
                muted: muted,
                textColor: textColor,
                isDark: isDark,
              ),
              const SizedBox(height: 14),
              _metric(
                label: 'Pace',
                valueA: _paceLabel(a),
                valueB: _paceLabel(b),
                a: _paceMinPerKm(a),
                b: _paceMinPerKm(b),
                labelA: _label(a),
                labelB: _label(b),
                accent: accent,
                muted: muted,
                textColor: textColor,
                isDark: isDark,
                note: 'menor é melhor',
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }

  Widget _monthDropdown({
    required MonthlyEvolutionStats selected,
    required Color color,
    required bool isDark,
    required ValueChanged<MonthlyEvolutionStats?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<MonthlyEvolutionStats>(
          value: selected,
          isExpanded: true,
          icon: Icon(LucideIcons.chevronDown, size: 16, color: color),
          dropdownColor: isDark ? AppColors.cardBackground : Colors.white,
          items: [
            for (final m in _months)
              DropdownMenuItem(
                value: m,
                child: Text(
                  _label(m),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  /// Grupo de métrica: duas barras horizontais (A em cima, B embaixo),
  /// escaladas pelo maior valor do par.
  Widget _metric({
    required String label,
    required String valueA,
    required String valueB,
    required String labelA,
    required String labelB,
    required double a,
    required double b,
    required Color accent,
    required Color muted,
    required Color textColor,
    required bool isDark,
    String? note,
  }) {
    final max = math.max(a, b);
    final barColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            if (note != null) ...[
              const Spacer(),
              Text(
                note,
                style: GoogleFonts.outfit(fontSize: 10, color: muted),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        _bar(labelA, valueA, a, max, accent, barColor),
        const SizedBox(height: 5),
        _bar(labelB, valueB, b, max, muted, barColor),
      ],
    );
  }

  Widget _bar(
    String monthLabel,
    String valueText,
    double value,
    double max,
    Color color,
    Color trackColor,
  ) {
    final fraction = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 42,
          child: Text(
            monthLabel,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 14,
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              widthFactor: fraction,
              heightFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 62,
          child: Text(
            valueText,
            textAlign: TextAlign.right,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
