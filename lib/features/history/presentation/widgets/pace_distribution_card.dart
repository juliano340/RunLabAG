import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/widgets/glass_container.dart';
import 'package:runlabag/core/domain/services/pace_zone_service.dart';
import 'pace_zone_legend.dart';

/// Card do dashboard com a rosquinha de distribuição de ritmo:
/// proporção da distância do período em cada faixa (caminhada, lento,
/// corrida, acelerando), com o total de km no centro.
class PaceDistributionCard extends StatelessWidget {
  final Map<PaceZone, double> distanceByZoneKm;

  /// Total oficial de km do período (KPI exibido no centro da rosquinha).
  final double totalKm;

  const PaceDistributionCard({
    super.key,
    required this.distanceByZoneKm,
    required this.totalKm,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final zones = PaceZone.values
        .where((z) => (distanceByZoneKm[z] ?? 0) > 0)
        .toList();
    if (zones.isEmpty) return const SizedBox.shrink();

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.pieChart, size: 16, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'DISTRIBUIÇÃO DE RITMO',
                style: GoogleFonts.outfit(
                  color: cs.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Proporção da distância por faixa de pace',
            style: GoogleFonts.outfit(
              color: cs.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 148,
                height: 148,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 44,
                        sections: zones.map((zone) {
                          return PieChartSectionData(
                            value: distanceByZoneKm[zone] ?? 0,
                            color: zone.color,
                            radius: 16,
                            showTitle: false,
                          );
                        }).toList(),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          totalKm.toStringAsFixed(1),
                          style: GoogleFonts.outfit(
                            color: cs.onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'km',
                          style: GoogleFonts.outfit(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: PaceZoneLegend(
                  distanceByZoneKm: distanceByZoneKm,
                  showBackground: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
