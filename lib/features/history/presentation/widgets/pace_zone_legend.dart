import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runlabag/core/domain/services/pace_zone_service.dart';

/// Legenda das faixas de ritmo exibida sobre o mapa colorido.
///
/// Cada faixa mostra um ponto colorido, o nome e o percentual da distância
/// total percorrida naquela faixa (ex.: "● Caminhada 32%").
class PaceZoneLegend extends StatelessWidget {
  final Map<PaceZone, double> distanceByZoneKm;

  /// Quando false, remove o fundo de vidro (para uso dentro de cards).
  final bool showBackground;

  const PaceZoneLegend({
    super.key,
    required this.distanceByZoneKm,
    this.showBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalKm = distanceByZoneKm.values.fold<double>(0, (a, b) => a + b);
    if (totalKm <= 0) return const SizedBox.shrink();

    // Ordem fixa das faixas, apenas as que têm distância.
    final zones = PaceZone.values
        .where((z) => (distanceByZoneKm[z] ?? 0) > 0)
        .toList();

    final chips = Wrap(
      spacing: 12,
      runSpacing: 8,
      children: zones.map((zone) {
        final percent =
            ((distanceByZoneKm[zone] ?? 0) / totalKm * 100).round();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: zone.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              '${zone.label} $percent%',
              style: GoogleFonts.outfit(
                color: cs.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ],
        );
      }).toList(),
    );

    if (!showBackground) return chips;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF162222) : Colors.white)
            .withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8),
        ],
      ),
      child: chips,
    );
  }
}
