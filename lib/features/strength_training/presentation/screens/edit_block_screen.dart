import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../domain/models/workout_block.dart';
import '../providers/strength_workout_provider.dart';

class EditBlockScreen extends StatefulWidget {
  final WorkoutBlock block;

  const EditBlockScreen({super.key, required this.block});

  @override
  State<EditBlockScreen> createState() => _EditBlockScreenState();
}

class _EditBlockScreenState extends State<EditBlockScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late List<BlockExercise> _exercises;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.block.name);
    _descriptionController = TextEditingController(text: widget.block.description ?? '');
    _exercises = List.from(widget.block.exercises);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addExercise() {
    showDialog(
      context: context,
      builder: (context) => _AddExerciseToBlockDialog(
        onSave: (name, sets, reps, weight, isTime) {
          setState(() {
            _exercises.add(BlockExercise(
              id: const Uuid().v4(),
              name: name,
              defaultSets: sets,
              defaultReps: reps,
              defaultWeight: weight,
              isTimeBased: isTime,
              orderIndex: _exercises.length,
            ));
          });
        },
      ),
    );
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dê um nome ao bloco')));
      return;
    }

    setState(() => _isSaving = true);
    
    final updatedBlock = WorkoutBlock(
      id: widget.block.id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      exercises: _exercises,
    );

    await context.read<StrengthWorkoutProvider>().saveBlock(updatedBlock);
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundDarkGreen,
        title: Text('Excluir Bloco?', style: GoogleFonts.outfit(color: AppColors.textLight)),
        content: Text('Este bloco será removido da biblioteca. Treinos que já usam este bloco não serão afetados.', style: GoogleFonts.outfit(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))),
        ],
      )
    );

    if (confirm == true && mounted) {
      await context.read<StrengthWorkoutProvider>().deleteBlock(widget.block.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.block.exercises.isEmpty ? 'Criar Bloco' : 'Editar Bloco',
          style: GoogleFonts.outfit(color: AppColors.textLight, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.trash2, color: AppColors.error),
            onPressed: _confirmDelete,
          ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.primaryNeon, strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(
                'Salvar',
                style: GoogleFonts.outfit(color: AppColors.primaryNeon, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'Nome do Bloco (ex: Peito)',
                      hintStyle: GoogleFonts.outfit(color: AppColors.textMuted.withValues(alpha: 0.5)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const Divider(color: AppColors.cardBorder),
                  TextField(
                    controller: _descriptionController,
                    style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Descrição curta (opcional)',
                      hintStyle: GoogleFonts.outfit(color: AppColors.textMuted.withValues(alpha: 0.5)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'EXERCÍCIOS',
                  style: GoogleFonts.outfit(
                    color: AppColors.primaryNeon,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'Arraste para reordenar',
                  style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (_exercises.isEmpty)
              _buildEmptyExercises()
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _exercises.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (oldIndex < newIndex) newIndex -= 1;
                    final item = _exercises.removeAt(oldIndex);
                    _exercises.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final ex = _exercises[index];
                  return Padding(
                    key: ValueKey(ex.id),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildExerciseTile(index, ex),
                  );
                },
              ),
            
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addExercise,
                icon: const Icon(LucideIcons.plusCircle, color: AppColors.primaryNeon),
                label: Text('Adicionar Exercício', style: GoogleFonts.outfit(color: AppColors.textLight)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: AppColors.primaryNeon.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyExercises() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(LucideIcons.dumbbell, color: AppColors.textMuted.withValues(alpha: 0.3), size: 48),
            const SizedBox(height: 12),
            Text(
              'Nenhum exercício neste bloco',
              style: GoogleFonts.outfit(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseTile(int index, BlockExercise ex) {
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(LucideIcons.gripVertical, color: AppColors.textMuted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ex.name,
                  style: GoogleFonts.outfit(color: AppColors.textLight, fontWeight: FontWeight.bold),
                ),
                Text(
                  ex.isTimeBased 
                    ? 'Por tempo' 
                    : '${ex.defaultSets} séries ${ex.defaultReps != null ? "x ${ex.defaultReps}" : ""}',
                  style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.edit2, color: AppColors.textMuted, size: 18),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => _AddExerciseToBlockDialog(
                  initialName: ex.name,
                  initialSets: ex.defaultSets,
                  initialReps: ex.defaultReps,
                  initialWeight: ex.defaultWeight,
                  initialIsTime: ex.isTimeBased,
                  onSave: (name, sets, reps, weight, isTime) {
                    setState(() {
                      _exercises[index] = BlockExercise(
                        id: ex.id,
                        name: name,
                        defaultSets: sets,
                        defaultReps: reps,
                        defaultWeight: weight,
                        isTimeBased: isTime,
                        orderIndex: index,
                      );
                    });
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(LucideIcons.trash2, color: AppColors.error.withValues(alpha: 0.7), size: 18),
            onPressed: () {
              setState(() => _exercises.removeAt(index));
            },
          ),
        ],
      ),
    );
  }
}

class _AddExerciseToBlockDialog extends StatefulWidget {
  final String? initialName;
  final int initialSets;
  final String? initialReps;
  final double? initialWeight;
  final bool initialIsTime;
  final Function(String name, int sets, String? reps, double? weight, bool isTime) onSave;

  const _AddExerciseToBlockDialog({
    this.initialName,
    this.initialSets = 3,
    this.initialReps = '12',
    this.initialWeight,
    this.initialIsTime = false,
    required this.onSave,
  });

  @override
  State<_AddExerciseToBlockDialog> createState() => _AddExerciseToBlockDialogState();
}

class _AddExerciseToBlockDialogState extends State<_AddExerciseToBlockDialog> {
  late TextEditingController _nameController;
  late TextEditingController _setsController;
  late TextEditingController _repsController;
  late TextEditingController _weightController;
  late bool _isTimeBased;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _setsController = TextEditingController(text: widget.initialSets.toString());
    _repsController = TextEditingController(text: widget.initialReps ?? '');
    _weightController = TextEditingController(text: widget.initialWeight?.toString() ?? '');
    _isTimeBased = widget.initialIsTime;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundDarkGreen,
      title: Text(widget.initialName == null ? 'Novo Exercício' : 'Editar Exercício', style: GoogleFonts.outfit(color: AppColors.textLight)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textLight),
              decoration: const InputDecoration(labelText: 'Nome', labelStyle: TextStyle(color: AppColors.textMuted)),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Por tempo?', style: TextStyle(color: AppColors.textLight)),
              value: _isTimeBased,
              onChanged: (val) => setState(() => _isTimeBased = val),
              activeColor: AppColors.primaryNeon,
            ),
            if (!_isTimeBased) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _setsController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textLight),
                      decoration: const InputDecoration(labelText: 'Séries', labelStyle: TextStyle(color: AppColors.textMuted)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _repsController,
                      style: const TextStyle(color: AppColors.textLight),
                      decoration: const InputDecoration(labelText: 'Reps', labelStyle: TextStyle(color: AppColors.textMuted)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppColors.textLight),
                decoration: const InputDecoration(labelText: 'Peso sugerido (Kg)', labelStyle: TextStyle(color: AppColors.textMuted)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNeon),
          onPressed: () {
            if (_nameController.text.trim().isNotEmpty) {
              widget.onSave(
                _nameController.text.trim(),
                int.tryParse(_setsController.text) ?? 3,
                _repsController.text.trim(),
                double.tryParse(_weightController.text),
                _isTimeBased,
              );
              Navigator.pop(context);
            }
          },
          child: const Text('Salvar', style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }
}
