import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, LengthLimitingTextInputFormatter;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/domain/repositories/run_repository.dart';
import '../../../../core/domain/repositories/stats_repository.dart';
import '../../../../core/domain/repositories/user_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../run/domain/services/run_metrics_service.dart';
import '../widgets/route_drawing_map.dart';
import 'package:runlabag/core/domain/models/run_model.dart';

enum _Effort { forte, normal, leve, alternada }

const _effortLabels = {
  _Effort.forte: 'Corri forte',
  _Effort.normal: 'Normal',
  _Effort.leve: 'Corri leve',
  _Effort.alternada: 'Corri e caminhei',
};

/// Fator sobre o ritmo médio do atleta (min/km) para cada nível de esforço.
const _effortFactors = {
  _Effort.forte: 0.93,
  _Effort.normal: 1.00,
  _Effort.leve: 1.10,
  _Effort.alternada: 1.25,
};

/// Fallback (min/km) quando o atleta ainda não tem ritmo médio registrado.
const _fallbackPaces = {
  _Effort.forte: 6.25,
  _Effort.normal: 6.75,
  _Effort.leve: 7.50,
  _Effort.alternada: 9.50,
};

/// Cadastro manual de treino — para a corrida que o aparelho perdeu.
///
/// Fluxo guiado: data → distância → rota opcional (desenho no mapa, que
/// preenche a distância) → esforço → duração pré-preenchida com estimativa
/// (ritmo médio real × fator do esforço), sempre editável. Duração zero é
/// bloqueada: lição do bug do recorde "10km em 00:00" aplicada na fonte.
class AddRunScreen extends StatefulWidget {
  const AddRunScreen({super.key, this.existingRun});

  /// Quando informado, a tela opera em modo EDIÇÃO: campos pré-preenchidos,
  /// o treino existente é atualizado (mesmo id) e rota/splits são
  /// preservados a menos que o usuário os altere.
  final RunModel? existingRun;

  @override
  State<AddRunScreen> createState() => _AddRunScreenState();
}

class _AddRunScreenState extends State<AddRunScreen> {
  StatsRepository get _statsRepo => context.read<StatsRepository>();
  UserRepository get _userRepo => context.read<UserRepository>();
  RunRepository get _runRepo => context.read<RunRepository>();
  BackupService get _backupService => context.read<BackupService>();
  final _distanceController = TextEditingController();
  final _durationController = TextEditingController();

  bool get _isEditing => widget.existingRun != null;

  DateTime _date = DateTime.now();
  _Effort _effort = _Effort.normal;
  // Quando o usuário digita a duração, a estimativa para de sobrescrever.
  bool _durationTouched = false;
  List<LatLng> _routePoints = const [];
  bool _routeTouched = false; // rota re-desenhada no modo edição
  String? _selectedType; // tipo explícito no modo edição
  double? _avgPaceMinPerKm; // âncora da estimativa (histórico real)
  double _weightKg = 0;
  bool _isSaving = false;

  /// Tipos de atividade disponíveis na edição.
  static const _runTypes = ['Corrida', 'Corrida/Caminhada', 'Caminhada'];

  @override
  void initState() {
    super.initState();
    final run = widget.existingRun;
    if (run != null) {
      _date = run.date;
      _distanceController.text = run.distanceKm.toStringAsFixed(2);
      _durationController.text =
          RunMetricsService.formatDuration(run.durationSeconds);
      // Não deixar a estimativa sobrescrever o valor carregado.
      _durationTouched = true;
      _routePoints = run.route
          .firstWhere((s) => s.isNotEmpty, orElse: () => const [])
          .toList();
      _selectedType = run.type;
    }
    _loadAnchors();
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _loadAnchors() async {
    final stats = await _statsRepo.getUserStats();
    final profile = await _userRepo.getUserProfile();
    if (!mounted) return;

    // Ritmo médio tipado; a UI não faz parse de string formatada.
    final paceMinutes = stats.averagePaceMinutesPerKm;
    final pace = paceMinutes > 0 ? paceMinutes : null;

    setState(() {
      _avgPaceMinPerKm = pace;
      _weightKg = profile?.weight ?? 0;
    });
    _refreshEstimate();
  }

  double get _distanceKm =>
      double.tryParse(_distanceController.text.replaceAll(',', '.')) ?? 0;

  int? get _durationSeconds =>
      RunMetricsService.parseDurationInput(_durationController.text);

  /// Ritmo (min/km) usado na estimativa: ritmo médio real × fator do esforço.
  double get _estimatePace =>
      (_avgPaceMinPerKm ?? _fallbackPaces[_effort]!) * _effortFactors[_effort]!;

  int get _estimateSeconds {
    final distance = _distanceKm;
    if (distance <= 0) return 0;
    return (_estimatePace * distance * 60).round();
  }

  void _refreshEstimate() {
    if (_durationTouched) return;
    final estimate = _estimateSeconds;
    _durationController.text =
        estimate > 0 ? RunMetricsService.formatDuration(estimate) : '';
  }

  bool get _canSave =>
      !_isSaving && _distanceKm > 0 && (_durationSeconds ?? 0) > 0;

  // ── Ações ─────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _drawRoute() async {
    final points = await Navigator.push<List<LatLng>>(
      context,
      MaterialPageRoute(
        builder: (_) => RouteDrawingMap(
          title: 'Desenhar Rota',
          confirmLabel: 'CONFIRMAR ROTA',
          initialPoints: _routePoints,
          onConfirm: (p, _) => Navigator.pop(context, p),
        ),
      ),
    );
    if (points == null) return;

    setState(() {
      _routeTouched = true;
      _routePoints = points;
      if (points.isNotEmpty) {
        // A rota desenhada é a fonte da verdade da distância.
        _distanceController.text =
            RouteDrawingMap.distanceKm(points).toStringAsFixed(2);
      }
    });
    _refreshEstimate();
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);

    final duration = _durationSeconds!;
    final distance = _distanceKm;
    final now = DateTime.now();
    // Edição preserva o horário original do treino; criação usa o agora.
    final source = _isEditing ? widget.existingRun!.date : now;
    final date = DateTime(
      _date.year,
      _date.month,
      _date.day,
      source.hour,
      source.minute,
    );

    final RunModel run;
    if (_isEditing) {
      // Edição: preserva rota/tempos/voltas/mood — só o que o usuário
      // mudou é sobrescrito.
      final base = widget.existingRun!;
      run = RunModel(
        id: base.id,
        date: date,
        distanceKm: distance,
        durationSeconds: duration,
        pausedDurationSeconds: base.pausedDurationSeconds,
        pace: RunMetricsService.calculatePace(duration, distance),
        calories: _weightKg > 0
            ? RunMetricsService.calculateCalories(distance, _weightKg)
            : base.calories,
        route: _routeTouched
            ? (_routePoints.isEmpty ? const [] : [_routePoints])
            : base.route,
        routeTimes: _routeTouched ? const [] : base.routeTimes,
        type: _selectedType ?? base.type,
        mood: base.mood,
        splits: base.splits,
        autoPauses: base.autoPauses,
      );
    } else {
      run = RunModel(
        id: const Uuid().v4(),
        date: date,
        distanceKm: distance,
        durationSeconds: duration,
        pace: RunMetricsService.calculatePace(duration, distance),
        calories: _weightKg > 0
            ? RunMetricsService.calculateCalories(distance, _weightKg)
            : 0,
        route: _routePoints.isEmpty ? const [] : [_routePoints],
        // Rota desenhada não tem tempos por ponto: fica vazia e o mapa
        // colorido cai no fallback (ritmo médio do treino).
        routeTimes: const [],
        splits: const [],
        // Esforço "corri e caminhei" vira tipo próprio na listagem.
        type: _effort == _Effort.alternada ? 'Corrida/Caminhada' : 'Corrida',
      );
    }

    try {
      await _runRepo.saveRun(run);
      unawaited(_backupService.runAutoBackupIfEnabled());
      if (!mounted) return;
      // O repositório emite a mudança e as abas dependentes recarregam.
      Navigator.pop(context, run);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao salvar o treino. Tente novamente.',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────

  TextStyle _labelStyle(ColorScheme cs) => GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant,
      );

  Widget _buildSection({
    required String label,
    required Widget child,
    String? caption,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle(cs)),
        const SizedBox(height: 8),
        child,
        if (caption != null) ...[
          const SizedBox(height: 6),
          Text(
            caption,
            style: GoogleFonts.outfit(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  Widget _buildDateRow(ColorScheme cs) {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.calendar, size: 16, color: cs.primary),
            const SizedBox(width: 10),
            Text(
              '${_date.day.toString().padLeft(2, '0')}/'
              '${_date.month.toString().padLeft(2, '0')}/${_date.year}',
              style: GoogleFonts.outfit(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(LucideIcons.chevronRight, size: 16, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteRow(ColorScheme cs) {
    final hasRoute = _routePoints.isNotEmpty;
    final routeKm =
        hasRoute ? RouteDrawingMap.distanceKm(_routePoints) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.mapPin, size: 16, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasRoute
                      ? '${_routePoints.length} pontos · ${routeKm.toStringAsFixed(2)} km'
                      : 'Aproxima a rota real do percurso',
                  style: GoogleFonts.outfit(
                    color: cs.onSurface,
                    fontWeight: hasRoute ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 13,
                  ),
                ),
                if (!hasRoute)
                  Text(
                    'Desenhada — preenche a distância',
                    style: GoogleFonts.outfit(
                      color: cs.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          if (hasRoute)
            GestureDetector(
              onTap: () => setState(() => _routePoints = const []),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child:
                    Icon(LucideIcons.eraser, size: 16, color: cs.onSurfaceVariant),
              ),
            ),
          GestureDetector(
            onTap: _drawRoute,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                hasRoute ? 'EDITAR' : 'DESENHAR',
                style: GoogleFonts.outfit(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Seletor do tipo de atividade (modo edição).
  Widget _buildTypeChips(ColorScheme cs) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _runTypes.map((type) {
        final selected = _selectedType == type;
        final chipColor = type == 'Caminhada'
            ? Colors.blueAccent
            : type == 'Corrida/Caminhada'
                ? Colors.orangeAccent
                : cs.primary;
        return GestureDetector(
          onTap: () => setState(() => _selectedType = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? chipColor.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? chipColor
                    : cs.outline.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              type,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? chipColor : cs.onSurfaceVariant,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEffortChips(ColorScheme cs) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _Effort.values.map((effort) {
        final selected = _effort == effort;
        return GestureDetector(
          onTap: () {
            setState(() => _effort = effort);
            _refreshEstimate();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? cs.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? cs.primary : cs.outline.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              _effortLabels[effort]!,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummary(ColorScheme cs) {
    final duration = _durationSeconds;
    final distance = _distanceKm;
    final valid = duration != null && duration > 0 && distance > 0;

    final pace = valid ? RunMetricsService.calculatePace(duration, distance) : '--:--';
    final kcal = valid && _weightKg > 0
        ? RunMetricsService.calculateCalories(distance, _weightKg).toString()
        : '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark
                ? AppColors.primaryNeon
                : AppColors.lightPrimary)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (Theme.of(context).brightness == Brightness.dark
                  ? AppColors.primaryNeon
                  : AppColors.lightPrimary)
              .withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text('PACE', style: _labelStyle(cs)),
              const SizedBox(height: 2),
              Text(
                '$pace /km',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          Column(
            children: [
              Text('CALORIAS', style: _labelStyle(cs)),
              const SizedBox(height: 2),
              Text(
                '$kcal kcal',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isEditing ? 'Editar Treino' : 'Novo Treino',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(label: 'Data', child: _buildDateRow(cs)),
              const SizedBox(height: 20),
              _buildSection(
                label: 'Distância',
                child: TextField(
                  controller: _distanceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^[0-9.,]*$')),
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    suffixText: 'km',
                    hintText: 'ex.: 10.0',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _refreshEstimate();
                  },
                ),
              ),
              const SizedBox(height: 20),
              _buildSection(
                label: 'Rota (opcional)',
                child: _buildRouteRow(cs),
              ),
              const SizedBox(height: 20),
              _buildSection(
                label: _isEditing ? 'Tipo' : 'Esforço',
                child: _isEditing
                    ? _buildTypeChips(cs)
                    : _buildEffortChips(cs),
                caption: _isEditing
                    ? null
                    : (_avgPaceMinPerKm != null
                          ? 'Sugestão baseada no teu ritmo médio de '
                                '${_formatPace(_avgPaceMinPerKm!)}/km'
                          : 'Sugestão padrão — ajuste como quiser'),
              ),
              const SizedBox(height: 20),
              _buildSection(
                label: 'Duração',
                child: Column(
                  children: [
                    TextField(
                      controller: _durationController,
                      keyboardType: TextInputType.text,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^[0-9:]*$')),
                        LengthLimitingTextInputFormatter(8),
                      ],
                      decoration: InputDecoration(
                        hintText: 'ex.: 47:30',
                        errorText: _durationController.text.isNotEmpty &&
                                _durationSeconds == null
                            ? 'Use mm:ss ou h:mm:ss'
                            : null,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {
                        _durationTouched = true;
                      }),
                    ),
                    if (!_isEditing && _durationTouched && _estimateSeconds > 0)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            setState(() => _durationTouched = false);
                            _refreshEstimate();
                          },
                          child: Text(
                            'Usar estimativa de novo',
                            style: GoogleFonts.outfit(fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSummary(cs),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _canSave ? _save : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: _canSave
                        ? cs.primary
                        : cs.primary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.check, size: 16, color: cs.onPrimary),
                      const SizedBox(width: 8),
                      Text(
                        _isSaving ? 'SALVANDO...' : 'SALVAR TREINO',
                        style: GoogleFonts.outfit(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Minutos decimais → "m:ss" (para exibir o ritmo médio do atleta).
  String _formatPace(double minutes) {
    final m = minutes.toInt();
    final s = ((minutes - m) * 60).round();
    if (s >= 60) return '${m + 1}:00';
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
