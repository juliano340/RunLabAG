import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, LengthLimitingTextInputFormatter;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/domain/repositories/run_repository.dart';
import '../../../../core/domain/repositories/user_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../run/domain/services/run_metrics_service.dart';
import 'package:runlabag/core/domain/services/pace_zone_service.dart';
import '../widgets/route_drawing_map.dart';
import 'package:runlabag/core/domain/models/run_model.dart';

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
  RunRepository get _runRepo => context.read<RunRepository>();
  UserRepository get _userRepo => context.read<UserRepository>();
  BackupService get _backupService => context.read<BackupService>();

  // ── Salvamento ────────────────────────────────────────────────────────

  Future<void> _save(List<LatLng> points, bool appendToGuide) async {
    if (_isSaving || points.length < 2) return;
    setState(() => _isSaving = true);

    final drawnKm = RouteDrawingMap.distanceKm(points);

    // Adicionar: o traçado vira um NOVO segmento depois da rota original
    // (nunca atravessa a pausa/gap) e a distância é SOMADA à registrada —
    // é para isso que o modo existe: completar um pedaço que o GPS não
    // registrou sem zerar o que já estava lá.
    // Refazer: comportamento antigo — o traçado substitui tudo.
    final List<List<LatLng>> newRoute;
    final double newDistanceKm;
    if (appendToGuide) {
      newRoute = [...widget.run.route, points];
      newDistanceKm = widget.run.distanceKm + drawnKm;
    } else {
      newRoute = [points];
      newDistanceKm = drawnKm;
    }

    // copyWith(route:) limpa routeTimes — repassamos para preservar os
    // tempos por ponto do trecho GPS; o trecho riscado entra com tempos
    // estimados (só para colorir o mapa), quando dá para estimar.
    final List<List<int>> newRouteTimes;
    if (appendToGuide) {
      final estimated = _estimatedTimesForDrawn(points);
      newRouteTimes = estimated != null
          ? [...widget.run.routeTimes, estimated]
          : const <List<int>>[];
    } else {
      newRouteTimes = const <List<int>>[];
    }

    var updated = widget.run.copyWith(
      route: newRoute,
      routeTimes: newRouteTimes,
      distanceKm: newDistanceKm,
    );
    var didUpdateMetrics = false;

    if (!appendToGuide) {
      // Refazer: mantém o diálogo — a distância "oficial" passa a ser a
      // da rota desenhada e o usuário decide recalcular as métricas.
      if (drawnKm > 0) {
        final newDuration = await _askUpdateMetrics(drawnKm);
        if (newDuration != null) {
          final profile = await _userRepo.getUserProfile();
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
    } else {
      // Adicionar: o tempo do trecho riscado JÁ está dentro da duração
      // registrada (a corrida aconteceu) — soma a distância e atualiza
      // pace/calorias na hora, sem perguntar.
      final profile = await _userRepo.getUserProfile();
      final duration = updated.durationSeconds;
      updated = updated.copyWith(
        pace: duration > 0
            ? RunMetricsService.calculatePace(duration, newDistanceKm)
            : updated.pace,
        calories: (profile != null && profile.weight > 0)
            ? RunMetricsService.calculateCalories(newDistanceKm, profile.weight)
            : updated.calories,
      );
      didUpdateMetrics = true;
    }

    try {
      await _runRepo.saveRun(updated);
      // Faixas de ritmo: rota e distância mudaram — as salvas na gravação
      // original ficariam velhas. Depois do save, em segundo plano.
      unawaited(_refreshPaceZones(updated));
      unawaited(_backupService.runAutoBackupIfEnabled());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appendToGuide
                ? 'Trecho adicionado! +${drawnKm.toStringAsFixed(2)} km'
                : didUpdateMetrics
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

  /// Tempos por ponto do trecho riscado, estimados com o pace médio do
  /// treino. O riscado não tem tempo real — a estimativa existe apenas
  /// para manter os arrays paralelos válidos e a coloração por pontos do
  /// trecho GPS original intacta. Devolve null quando não dá para
  /// estimar (sem duração ou sem tempos por ponto válidos).
  List<int>? _estimatedTimesForDrawn(List<LatLng> points) {
    final route = widget.run.route;
    final routeTimes = widget.run.routeTimes;
    final hasValidTimes = routeTimes.length == route.length &&
        routeTimes.every((segment) => segment.isNotEmpty);
    final duration = widget.run.durationSeconds;
    final distanceKm = widget.run.distanceKm;
    if (!hasValidTimes || duration <= 0 || distanceKm <= 0) return null;

    final lastTime = routeTimes.last.last;
    final paceSecPerKm = duration / distanceKm;
    final times = <int>[lastTime];
    var cumulativeKm = 0.0;
    for (var i = 1; i < points.length; i++) {
      cumulativeKm += Geolocator.distanceBetween(
            points[i - 1].latitude,
            points[i - 1].longitude,
            points[i].latitude,
            points[i].longitude,
          ) /
          1000;
      times.add(lastTime + (cumulativeKm * paceSecPerKm).round());
    }
    return times;
  }

  /// Recalcula as faixas de ritmo do treino no banco: rota e distância
  /// mudaram, e as salvas na gravação original ficariam velhas.
  Future<void> _refreshPaceZones(RunModel run) async {
    try {
      final zones = PaceZoneService.analyze(
        route: run.route,
        routeTimes: run.routeTimes,
        distanceKm: run.distanceKm,
        durationSeconds: run.durationSeconds,
        splits: run.splits,
      );
      await _runRepo.savePaceZones(
        run.id,
        {for (final e in zones.distanceByZoneKm.entries) e.key.name: e.value},
      );
    } catch (e) {
      debugPrint('Falha ao atualizar faixas de ritmo: $e');
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
      appendConfirmLabel: 'ADICIONAR TRECHO',
      allowAppend: true,
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
