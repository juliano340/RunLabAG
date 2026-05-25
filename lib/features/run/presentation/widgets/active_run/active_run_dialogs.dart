import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/services/pacing_service.dart';

class ActiveRunDialogs {
  static Future<bool?> showDiscardConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.backgroundDarkGreen
            : Colors.white,
        title: Text(
          'Descartar Treino?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'Tem certeza? Todos os dados do treino serão perdidos e não poderão ser recuperados.',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : AppColors.textMutedDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'CONFIRMAR DESCARTE AGORA',
              style: GoogleFonts.outfit(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<bool?> showExitConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.backgroundDarkGreen
            : Colors.white,
        title: Text(
          'Sair da Corrida?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'Tem certeza que deseja sair? O progresso não salvo será perdido.',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : AppColors.textMutedDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'CANCELAR',
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'SAIR',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  static Future<bool?> showShortRunWarning(BuildContext context, int distanceMeters, int seconds) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.backgroundDarkGreen
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.orangeAccent, width: 1),
        ),
        title: Row(
          children: [
            const Icon(LucideIcons.alertTriangle, color: Colors.orangeAccent),
            const SizedBox(width: 10),
            Text(
              'Treino Curto',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Este treino parece muito curto (${distanceMeters}m em ${seconds} s). Deseja descartá-lo ou salvar assim mesmo?',
          style: GoogleFonts.outfit(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textMuted
                : AppColors.textMutedDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'DESCARTAR AGORA!',
              style: GoogleFonts.outfit(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNeon,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'SALVAR ASSIM MESMO',
              style: GoogleFonts.outfit(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<String?> showTrainingTypePicker(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.backgroundDarkGreen
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          32,
          24,
          32 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Como foi seu treino?',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Classifique sua atividade para melhor acompanhamento.',
              style: GoogleFonts.outfit(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textMuted
                    : AppColors.textMutedDark,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            _typeOption(
              context: context,
              type: 'Corrida',
              icon: LucideIcons.zap,
              color: AppColors.primaryNeon,
              description: 'Treino contínuo em ritmo de corrida.',
            ),
            const SizedBox(height: 16),
            _typeOption(
              context: context,
              type: 'Caminhada',
              icon: LucideIcons.footprints,
              color: Colors.blueAccent,
              description: 'Caminhada leve ou vigorosa.',
            ),
            const SizedBox(height: 16),
            _typeOption(
              context: context,
              type: 'Corrida/Caminhada',
              icon: LucideIcons.timer,
              color: Colors.orangeAccent,
              description: 'Alternância entre corrida e caminhada.',
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'CANCELAR',
                  style: GoogleFonts.outfit(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _typeOption({
    required BuildContext context,
    required String type,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, type),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          color: color.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type,
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textMuted
                          : AppColors.textMutedDark,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  static Future<String?> showMoodPicker(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.backgroundDarkGreen
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          32,
          24,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Como você se sentiu?',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Avalie sua experiência neste treino.',
              style: GoogleFonts.outfit(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textMuted
                    : AppColors.textMutedDark,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _moodOption(context, '😣', 'Ruim'),
                _moodOption(context, '😐', 'Médio'),
                _moodOption(context, '🙂', 'Bom'),
                _moodOption(context, '🤩', 'Excelente'),
              ],
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: Text(
                'PULAR',
                style: GoogleFonts.outfit(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textMuted
                      : AppColors.textMutedDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _moodOption(BuildContext context, String emoji, String label) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, emoji),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textMuted
                  : AppColors.textMutedDark,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  static void showGoalDialog(
    BuildContext context, {
    double? initialDistanceGoal,
    required Function(double distance, int? targetTimeSeconds, PacingService? pacingService) onGoalSet,
    required VoidCallback onNoGoal,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _GoalSelectionDialog(
        initialDistanceGoal: initialDistanceGoal,
        onGoalSelected: (distance, isCustom) {
          if (isCustom) {
            Navigator.pop(ctx);
            Future.delayed(const Duration(milliseconds: 150), () {
              _showTimeGoalDialog(context, distance, onGoalSet);
            });
          } else {
            Navigator.pop(ctx);
            _showTimeGoalDialog(context, distance, onGoalSet);
          }
        },
        onNoGoal: () {
          Navigator.pop(ctx);
          onNoGoal();
        },
      ),
    );
  }

  static void _showTimeGoalDialog(
    BuildContext context,
    double distance,
    Function(double distance, int? targetTimeSeconds, PacingService? pacingService) onGoalSet,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).brightness == Brightness.dark
            ? AppColors.backgroundDarkGreen
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Definir Tempo Alvo para ${distance.toInt()}km',
          style: TextStyle(
            color: Theme.of(ctx).colorScheme.onSurface,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _timeOption(ctx, distance, 5, 'Pace 5:00 (Forte)', onGoalSet),
            _timeOption(ctx, distance, 6, 'Pace 6:00 (Moderado)', onGoalSet),
            _timeOption(ctx, distance, 7, 'Pace 7:00 (Leve)', onGoalSet),
            const Divider(color: Colors.white24),
            ListTile(
              title: const Text(
                'Sem tempo alvo',
                style: TextStyle(color: Colors.white70),
              ),
              onTap: () {
                onGoalSet(distance, null, null);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget _timeOption(
    BuildContext ctx,
    double distance,
    int paceMinutes,
    String label,
    Function(double distance, int? targetTimeSeconds, PacingService? pacingService) onGoalSet,
  ) {
    final int totalSeconds = (distance * paceMinutes * 60).toInt();
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        'Total: ${paceMinutes * distance.toInt()} min',
        style: TextStyle(
          color: Theme.of(ctx).brightness == Brightness.dark
              ? AppColors.textMuted
              : AppColors.textMutedDark,
          fontSize: 12,
        ),
      ),
      onTap: () {
        final pacingService = PacingService(
          targetDistanceKm: distance,
          targetTimeSeconds: totalSeconds,
        );
        onGoalSet(distance, totalSeconds, pacingService);
        Navigator.pop(ctx);
      },
    );
  }
}

class _GoalSelectionDialog extends StatefulWidget {
  final double? initialDistanceGoal;
  final Function(double distance, bool isCustom) onGoalSelected;
  final VoidCallback onNoGoal;

  const _GoalSelectionDialog({
    required this.initialDistanceGoal,
    required this.onGoalSelected,
    required this.onNoGoal,
  });

  @override
  State<_GoalSelectionDialog> createState() => _GoalSelectionDialogState();
}

class _GoalSelectionDialogState extends State<_GoalSelectionDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  bool _showingCustom = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _switchToCustom() {
    setState(() => _showingCustom = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNode.canRequestFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.backgroundDarkGreen : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        _showingCustom ? 'Distância Personalizada' : 'Definir Meta de Corrida',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      content: _showingCustom ? _buildCustomView(isDark) : _buildPresetView(isDark),
      actions: _showingCustom
          ? [
              TextButton(
                onPressed: () {
                  _focusNode.unfocus();
                  setState(() {
                    _showingCustom = false;
                    _controller.clear();
                  });
                },
                child: Text(
                  'VOLTAR',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.primaryNeon : AppColors.lightPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  elevation: 0,
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final distance = double.tryParse(
                      _controller.text.replaceAll(',', '.'),
                    );
                    if (distance != null) {
                      widget.onGoalSelected(distance, true);
                    }
                  }
                },
                child: Text(
                  'CONFIRMAR',
                  style: GoogleFonts.outfit(
                    color: isDark ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]
          : null,
    );
  }

  Widget _buildPresetView(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Distância Alvo:', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 8),
        _goalItem(1.0, '1 km (Velocidade)'),
        _goalItem(3.0, '3 km (Leve)'),
        _goalItem(5.0, '5 km (Avançado)'),
        _goalItem(10.0, '10 km (Resistência)'),
        Divider(color: isDark ? Colors.white24 : Colors.black12),
        ListTile(
          leading: Icon(LucideIcons.pencil, color: isDark ? Colors.white38 : Colors.black38, size: 18),
          title: Text('Personalizado...', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
          onTap: _switchToCustom,
        ),
        Divider(color: isDark ? Colors.white24 : Colors.black12),
        ListTile(
          title: Text('Sem meta', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
          onTap: widget.onNoGoal,
        ),
      ],
    );
  }

  Widget _buildCustomView(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Digite a distância desejada em km:',
            style: TextStyle(
              color: isDark ? AppColors.textMuted : AppColors.textMutedDark,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: false,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.outfit(
              color: isDark ? Colors.white : AppColors.textDark,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'Ex: 7.5',
              hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 24),
              suffixText: 'km',
              suffixStyle: TextStyle(
                color: isDark ? AppColors.primaryNeon : AppColors.lightPrimary,
                fontWeight: FontWeight.bold,
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? AppColors.primaryNeon : AppColors.lightPrimary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Informe a distância';
              final parsed = double.tryParse(value.replaceAll(',', '.'));
              if (parsed == null) return 'Valor inválido';
              if (parsed < 0.5) return 'Mínimo: 0.5 km';
              if (parsed > 100) return 'Máximo: 100 km';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _goalItem(double value, String label) {
    final isSelected = widget.initialDistanceGoal == value;
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: isSelected
          ? const Icon(LucideIcons.check, color: AppColors.primaryNeon)
          : null,
      onTap: () => widget.onGoalSelected(value, false),
    );
  }
}
