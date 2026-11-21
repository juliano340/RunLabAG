import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, LengthLimitingTextInputFormatter;
import '../../../../core/services/backup_service.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../run/domain/services/run_metrics_service.dart';
import '../widgets/route_drawing_map.dart';

/// Tela para editar a rota de um treino já registrado.
///
/// O desenho acontece no [RouteDrawingMap] (retas ou a dedo). Ao salvar, um
/// diálogo pergunta se a distância, o pace e as calorias devem ser
/// recalculados com base na rota desenhada — treino sem duração pede o
/// tempo no diálogo. A rota original fica visível como guia esmaecida.
class EditRunRouteScreen extends StatefulWidget {
  final RunModel run;

  const EditRunRouteScreen({super.key, required this.run});

  @override
  State<EditRunRouteScreen> createState() => _EditRunRouteScreenState();
}

class _EditRunRouteScreenState extends State<EditRunRouteScreen> {
  bool _isSaving = false;

  // ── Salvamento ────────────────────────────────────────────────────────

  Future<void> _save(List<LatLng> points) async {
    if (_isSaving || points.length < 2) return;
    setState(() => _isSaving = true);

    final drawnKm = RouteDrawingMap.distanceKm(points);
    var updated = widget.run.copyWith(route: [points]);
    var didUpdateMetrics = false;

    if (drawnKm > 0) {
      final newDuration = await _askUpdateMetrics(drawnKm);
      if (newDuration != null) {
        final profile = await DatabaseService().getUserProfile();
        final newPace = RunMetricsService.calculatePace(newDuration, drawnKm);
        final newCalories = (profile != null && profile.weight > 0)
            ? RunMetricsService.calculateCalories(drawnKm, profile.weight)
            : updated.calories;
        updated = updated.copyWith(
          distanceKm: drawnKm,
          durationSeconds: newDuration,
          pace: newPace,
          calories: newCalories,
        );
        didUpdateMetrics = true;
      }
    }

    try {
      await DatabaseService().saveRun(updated);
      unawaited(BackupService().runAutoBackupIfEnabled());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            didUpdateMetrics
                ? 'Rota e métricas atualizadas!'
                : 'Rota atualizada!',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.primaryNeonDark,
        ),
      );
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao salvar a rota. Tente novamente.',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// Pergunta se as métricas devem ser recalculadas com base na rota
  /// desenhada. Devolve a duração a usar (null = manter como está).
  /// Treino sem duração registrada pede o tempo no diálogo — sem isso o
  /// pace viraria "0:00" e criaria recorde falso.
  Future<int?> _askUpdateMetrics(double drawnKm) {
    return showDialog<int>(
      context: context,
      builder: (_) => _UpdateMetricsDialog(
        drawnKm: drawnKm,
        registeredKm: widget.run.distanceKm,
        currentPace: widget.run.pace,
        existingDurationSeconds: widget.run.durationSeconds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RouteDrawingMap(
      title: 'Editar Rota',
      guideRoute: widget.run.route,
      confirmLabel: 'SALVAR ROTA',
      busy: _isSaving,
      onConfirm: _save,
    );
  }
}

/// Diálogo "Atualizar métricas?" da edição de rota.
///
/// Se o treino não tem duração registrada (durationSeconds = 0), exige o
/// tempo antes de permitir recalcular — sem ele o pace sairia "0:00".
class _UpdateMetricsDialog extends StatefulWidget {
  const _UpdateMetricsDialog({
    required this.drawnKm,
    required this.registeredKm,
    required this.currentPace,
    required this.existingDurationSeconds,
  });

  final double drawnKm;
  final double registeredKm;
  final String currentPace;
  final int existingDurationSeconds;

  @override
  State<_UpdateMetricsDialog> createState() => _UpdateMetricsDialogState();
}

class _UpdateMetricsDialogState extends State<_UpdateMetricsDialog> {
  final _durationController = TextEditingController();

  bool get _needsDuration => widget.existingDurationSeconds <= 0;

  int? get _durationSeconds {
    if (!_needsDuration) return widget.existingDurationSeconds;
    return RunMetricsService.parseDurationInput(_durationController.text);
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final duration = _durationSeconds;
    final newPace = duration == null
        ? null
        : RunMetricsService.calculatePace(duration, widget.drawnKm);

    return AlertDialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
      ),
      title: Text(
        'Atualizar métricas?',
        style: GoogleFonts.outfit(
          color: cs.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rota desenhada: ${widget.drawnKm.toStringAsFixed(2)} km',
            style: GoogleFonts.outfit(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Distância registrada: ${widget.registeredKm.toStringAsFixed(2)} km',
            style: GoogleFonts.outfit(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (_needsDuration) ...[
            Text(
              'Este treino não tem duração registrada. Informe quanto tempo '
              'você levou para o pace e as calorias fazerem sentido.',
              style: GoogleFonts.outfit(
                color: cs.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _durationController,
              autofocus: true,
              keyboardType: TextInputType.text,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^[0-9:]*$')),
                LengthLimitingTextInputFormatter(8),
              ],
              decoration: InputDecoration(
                labelText: 'Duração',
                hintText: 'ex.: 47:30',
                errorText:
                    _durationController.text.isNotEmpty && duration == null
                        ? 'Use mm:ss ou h:mm:ss'
                        : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ] else
            Text(
              'Ao atualizar, a distância, o pace (${widget.currentPace}/km → '
              '$newPace/km) e as calorias serão recalculados com base na '
              'rota desenhada.',
              style: GoogleFonts.outfit(
                color: cs.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(
            'MANTER REGISTRADO',
            style: GoogleFonts.outfit(color: cs.onSurfaceVariant),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: duration == null
              ? null
              : () => Navigator.pop(context, duration),
          child: Text(
            'ATUALIZAR',
            style: GoogleFonts.outfit(
              color: cs.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
