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

/// Comparativo entre dois blocos de meses com janela deslizante:
/// "últimos N meses" vs "os N meses imediatamente anteriores". As setas
/// deslizam a janela no tempo; o tamanho do bloco é 1, 3 ou 6 meses —
/// dá pra comparar o começo do ano com o meio do ano, por exemplo.
class PeriodComparisonSection extends StatefulWidget {
  const PeriodComparisonSection({super.key, required this.monthlyData});

  /// Meses do mais recente para o mais antigo (ordem do banco).
  final List<MonthlyEvolutionStats> monthlyData;

  @override
  State<PeriodComparisonSection> createState() =>
      _PeriodComparisonSectionState();
}

class _PeriodComparisonSectionState extends State<PeriodComparisonSection> {
  static const _windowOptions = [1, 3, 6];
  static const _windowLabels = ['1 mês', '3 meses', '6 meses'];

  int _windowMonths = 3;
  int _slide = 0; // 0 = blocos mais recentes; aumenta para trás no tempo.

  int get _maxSlide {
    final blocks = (widget.monthlyData.length / _windowMonths).floor();
    return math.max(0, blocks - 2); // dois blocos completos no mínimo
  }

  List<MonthlyEvolutionStats> _block(int index) {
    final start = _slide * _windowMonths + index * _windowMonths;
    final end = start + _windowMonths;
    if (start < 0 || end > widget.monthlyData.length) return const [];
    return widget.monthlyData.sublist(start, end);
  }

  ({double distance, int seconds, int runs, int calories}) _aggregate(
    List<MonthlyEvolutionStats> months,
  ) {
    var distance = 0.0;
    var seconds = 0;
    var runs = 0;
    var calories = 0;
    for (final m in months) {
      distance += m.totalDistance;
      seconds += m.totalDurationSeconds;
      runs += m.runCount;
      calories += m.totalCalories;
    }
    return (
      distance: distance,
      seconds: seconds,
      runs: runs,
      calories: calories,
    );
  }

  String _blockLabel(List<MonthlyEvolutionStats> months) {
    if (months.isEmpty) return '--';
    final oldest = months.last;
    final newest = months.first;
    final start = '${_monthShort[oldest.startDate.month - 1]}'
        '/${(oldest.startDate.year % 100).toString().padLeft(2, '0')}';
    final end = '${_monthShort[newest.startDate.month - 1]}'
        '/${(newest.startDate.year % 100).toString().padLeft(2, '0')}';
    return start == end ? end : '$start – $end';
  }

  double _paceMinPerKmOf(
    ({double distance, int seconds, int runs, int calories}) agg,
  ) {
    return agg.distance > 0 ? (agg.seconds / 60) / agg.distance : 0;
  }

  String _formatPace(double minutes) {
    if (minutes <= 0) return '--:--';
    final total = (minutes * 60).round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Delta de pace em segundos, com sinal ("−0:12" = ficou mais rápido).
  String _paceDeltaText(int deltaSeconds) {
    if (deltaSeconds == 0) return '0:00';
    final sign = deltaSeconds > 0 ? '+' : '-';
    final abs = deltaSeconds.abs();
    return '$sign${abs ~/ 60}:${(abs % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.textMuted : AppColors.textMutedDark;
    final accent = isDark ? AppColors.primaryNeon : AppColors.lightPrimary;
    final textColor = isDark ? AppColors.textLight : AppColors.textDark;

    // Slide além dos dados disponíveis: gruda no máximo possível.
    if (_slide > _maxSlide) _slide = _maxSlide;

    final recent = _aggregate(_block(0));
    final previous = _aggregate(_block(1));
    final hasBlocks = recent.runs + previous.runs > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título + tamanho da janela
        Row(
          children: [
            Text(
              'Comparativo',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const Spacer(),
            for (var i = 0; i < _windowOptions.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              _windowChip(i, isDark),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // Navegação temporal
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _slide < _maxSlide
                  ? () => setState(() => _slide++)
                  : null,
              icon: Icon(LucideIcons.chevronLeft, size: 18, color: muted),
            ),
            Expanded(
              child: Text(
                '${_blockLabel(_block(1))}  vs  ${_blockLabel(_block(0))}',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _slide > 0 ? () => setState(() => _slide--) : null,
              icon: Icon(LucideIcons.chevronRight, size: 18, color: muted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        hasBlocks
            ? GlassContainer(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    _headerRow(muted),
                    Divider(color: muted.withValues(alpha: 0.15), height: 1),
                    _buildRow(
                      label: 'Distância',
                      previous:
                          '${previous.distance.toStringAsFixed(1)} km',
                      current:
                          '${recent.distance.toStringAsFixed(1)} km',
                      deltaText:
                          '${recent.distance - previous.distance >= 0 ? '+' : ''}'
                          '${(recent.distance - previous.distance).toStringAsFixed(1)} km',
                      hasDelta: true,
                      isGood: recent.distance - previous.distance > 0.01,
                      muted: muted,
                      textColor: textColor,
                      accent: accent,
                    ),
                    _divider(muted),
                    _buildRow(
                      label: 'Treinos',
                      previous: '${previous.runs}',
                      current: '${recent.runs}',
                      deltaText:
                          '${recent.runs - previous.runs >= 0 ? '+' : ''}'
                          '${recent.runs - previous.runs}',
                      hasDelta: true,
                      isGood: recent.runs - previous.runs > 0,
                      muted: muted,
                      textColor: textColor,
                      accent: accent,
                    ),
                    _divider(muted),
                    _buildRow(
                      label: 'Pace',
                      previous:
                          '${_formatPace(_paceMinPerKmOf(previous))}/km',
                      current: '${_formatPace(_paceMinPerKmOf(recent))}/km',
                      deltaText: _paceDeltaText(
                        ((_paceMinPerKmOf(recent) - _paceMinPerKmOf(previous)) *
                                60)
                            .round(),
                      ),
                      hasDelta: previous.distance > 0 && recent.distance > 0,
                      isGood: _paceMinPerKmOf(recent) <
                          _paceMinPerKmOf(previous),
                      muted: muted,
                      textColor: textColor,
                      accent: accent,
                    ),
                    _divider(muted),
                    _buildRow(
                      label: 'Calorias',
                      previous: '${previous.calories} kcal',
                      current: '${recent.calories} kcal',
                      deltaText:
                          '${recent.calories - previous.calories >= 0 ? '+' : ''}'
                          '${recent.calories - previous.calories}',
                      hasDelta: true,
                      isGood: recent.calories - previous.calories > 0,
                      muted: muted,
                      textColor: textColor,
                      accent: accent,
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Sem dados suficientes para comparar — registre treinos em '
                  'pelo menos dois meses.',
                  style: GoogleFonts.outfit(fontSize: 11, color: muted),
                ),
              ),
        if (_slide == 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'O bloco recente inclui o mês em andamento.',
              style: GoogleFonts.outfit(fontSize: 10, color: muted),
            ),
          ),
      ],
    );
  }

  Widget _windowChip(int index, bool isDark) {
    final selected = _windowMonths == _windowOptions[index];
    final accent = isDark ? AppColors.primaryNeon : AppColors.lightPrimary;
    return GestureDetector(
      onTap: () {
        if (_windowMonths == _windowOptions[index]) return;
        setState(() {
          _windowMonths = _windowOptions[index];
          if (_slide > _maxSlide) _slide = _maxSlide;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent : accent.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          _windowLabels[index],
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: selected ? accent : accent.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _headerRow(Color muted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 4),
      child: Row(
        children: [
          const SizedBox(width: 64),
          Expanded(
            child: Text(
              'Anterior',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 9, color: muted),
            ),
          ),
          SizedBox(
            width: 58,
            child: Text(
              'Δ',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 9, color: muted),
            ),
          ),
          Expanded(
            child: Text(
              'Recente',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 9, color: muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow({
    required String label,
    required String previous,
    required String current,
    required String deltaText,
    required bool hasDelta,
    required bool isGood,
    required Color muted,
    required Color textColor,
    required Color accent,
  }) {
    var deltaColor = muted;
    if (hasDelta) {
      deltaColor = isGood ? accent : AppColors.error;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: GoogleFonts.outfit(fontSize: 11, color: muted),
            ),
          ),
          Expanded(
            child: Text(
              previous,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 12, color: textColor),
            ),
          ),
          SizedBox(
            width: 58,
            child: Text(
              deltaText,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: deltaColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              current,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(Color muted) {
    return Divider(color: muted.withValues(alpha: 0.12), height: 1);
  }
}
