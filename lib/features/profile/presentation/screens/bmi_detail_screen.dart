import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/user_profile.dart';

class BmiDetailScreen extends StatelessWidget {
  final UserProfile profile;

  const BmiDetailScreen({super.key, required this.profile});

  static const double _minScale = 15.0;
  static const double _maxScale = 40.0;

  static Color statusColor(double bmi) {
    if (bmi < 18.5) return const Color(0xFF38BDF8);
    if (bmi < 25) return const Color(0xFF22C55E);
    if (bmi < 30) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final bmi = profile.bmi;
    final color = statusColor(bmi);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Índice de Massa Corporal',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(context, bmi, color),
          const SizedBox(height: 32),
          Text(
            'ONDE VOCÊ ESTÁ',
            style: GoogleFonts.outfit(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _BmiGauge(bmi: bmi),
          const SizedBox(height: 32),
          ..._buildCategoryCards(context, bmi),
          const SizedBox(height: 24),
          _buildIdealWeightCard(context),
          const SizedBox(height: 24),
          Text(
            'O IMC é uma referência geral e não considera composição corporal '
            '(massa muscular, densidade óssea). Atletas podem ter IMC elevado '
            'sem excesso de gordura. Consulte um profissional de saúde.',
            style: GoogleFonts.outfit(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, double bmi, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.heartPulse, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bmi.toStringAsFixed(1),
                  style: GoogleFonts.outfit(
                    color: color,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.bmiStatus,
                  style: GoogleFonts.outfit(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${profile.weight.toStringAsFixed(1)} kg · ${profile.height.toInt()} cm',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCategoryCards(BuildContext context, double bmi) {
    const categories = [
      ('Abaixo do peso', '< 18,5', Color(0xFF38BDF8)),
      ('Peso normal', '18,5 – 24,9', Color(0xFF22C55E)),
      ('Sobrepeso', '25,0 – 29,9', Color(0xFFF59E0B)),
      ('Obesidade', '≥ 30,0', Color(0xFFEF4444)),
    ];

    return categories.map((category) {
      final isCurrent = category.$1 == profile.bmiStatus;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isCurrent ? category.$3.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrent
                ? category.$3.withValues(alpha: 0.5)
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: category.$3,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category.$1,
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            Text(
              category.$2,
              style: GoogleFonts.outfit(
                color: isCurrent
                    ? category.$3
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isCurrent) ...[
              const SizedBox(width: 8),
              Icon(LucideIcons.check,
                  color: category.$3, size: 16),
            ],
          ],
        ),
      );
    }).toList();
  }

  Widget _buildIdealWeightCard(BuildContext context) {
    final hMeters = profile.height / 100;
    final minWeight = 18.5 * hMeters * hMeters;
    final maxWeight = 24.9 * hMeters * hMeters;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryNeon.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryNeon.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.scale, color: AppColors.primaryNeon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Faixa de peso ideal para ${profile.height.toInt()} cm',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${minWeight.toStringAsFixed(1)} – ${maxWeight.toStringAsFixed(1)} kg',
                  style: GoogleFonts.outfit(
                    color: AppColors.primaryNeon,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BmiGauge extends StatelessWidget {
  final double bmi;

  const _BmiGauge({required this.bmi});

  static const double _min = BmiDetailScreen._minScale;
  static const double _max = BmiDetailScreen._maxScale;

  double get _markerFraction =>
      ((bmi - _min) / (_max - _min)).clamp(0.02, 0.98);

  Color get _currentColor => BmiDetailScreen.statusColor(bmi);

  @override
  Widget build(BuildContext context) {
    const segments = [
      (3.5, Color(0xFF38BDF8)),
      (6.5, Color(0xFF22C55E)),
      (5.0, Color(0xFFF59E0B)),
      (10.0, Color(0xFFEF4444)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return Column(
          children: [
            SizedBox(
              height: 64,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 26,
                    bottom: 22,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: segments
                            .map((segment) => Expanded(
                                  flex: segment.$1.toInt(),
                                  child: ColoredBox(color: segment.$2),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                  Positioned(
                    left: width * _markerFraction - 2,
                    top: 20,
                    bottom: 16,
                    width: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: (width * _markerFraction - 30)
                        .clamp(0.0, width - 60),
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _currentColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        bmi.toStringAsFixed(1),
                        style: GoogleFonts.outfit(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 18,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _tick(width, _min, _min.toStringAsFixed(0), alignLeft: true),
                  _boundaryTick(width, 18.5),
                  _boundaryTick(width, 25),
                  _boundaryTick(width, 30),
                  _tick(width, _max, _max.toStringAsFixed(0), alignLeft: false),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tick(double width, double value, String label,
      {required bool alignLeft}) {
    return Positioned(
      left: alignLeft ? 0 : null,
      right: alignLeft ? null : 0,
      child: Text(
        label,
        style: GoogleFonts.outfit(
          color: Colors.grey.shade500,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _boundaryTick(double width, double value) {
    final fraction = (value - _min) / (_max - _min);
    return Positioned(
      left: width * fraction - 10,
      width: 20,
      child: Text(
        value.toStringAsFixed(1).replaceAll('.', ','),
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          color: Colors.grey.shade500,
          fontSize: 11,
        ),
      ),
    );
  }
}
