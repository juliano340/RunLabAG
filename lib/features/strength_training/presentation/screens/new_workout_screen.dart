import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../domain/models/strength_workout.dart';
import '../providers/strength_workout_provider.dart';

class NewWorkoutScreen extends StatefulWidget {
  final StrengthWorkout? template;
  final bool isEditing;

  const NewWorkoutScreen({super.key, this.template, this.isEditing = false});

  @override
  State<NewWorkoutScreen> createState() => _NewWorkoutScreenState();
}

class _NewWorkoutScreenState extends State<NewWorkoutScreen> {
  late DateTime _selectedDate;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  List<WorkoutMuscleGroup> _muscleGroups = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    
    if (widget.template != null) {
      _nameController.text = widget.template!.name;
      _notesController.text = widget.template!.notes ?? '';
      _selectedDate = widget.template!.date ?? DateTime.now();
      
      if (widget.isEditing) {
        _muscleGroups = List.from(widget.template!.muscleGroups);
      } else {
        // Clone the groups but reset sets if needed, for instance cloning a template
        _muscleGroups = widget.template!.muscleGroups.map((g) => g.copyWith(
          id: const Uuid().v4(), // New ID for instance
          exercises: g.exercises.map((e) => e.copyWith(
            id: const Uuid().v4(),
            sets: e.sets.map((s) => s.copyWith(id: const Uuid().v4(), isCompleted: false)).toList(),
          )).toList(),
        )).toList();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryNeon,
              onPrimary: Colors.black,
              surface: AppColors.backgroundDarkGreen,
              onSurface: AppColors.textLight,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addMuscleGroup() {
    _showAddDialog(
      title: 'Adicionar Grupo Muscular',
      hint: 'Ex: Peito, Costas, Pernas',
      onSave: (name) {
        setState(() {
          _muscleGroups.add(WorkoutMuscleGroup(
            id: const Uuid().v4(),
            name: name,
          ));
        });
      },
    );
  }

  void _addExercise(int groupIndex) {
    showDialog(
      context: context,
      builder: (context) => _BulkExerciseDialog(
        groupName: _muscleGroups[groupIndex].name,
        onSave: (name, sets, reps, weight) {
          setState(() {
            final group = _muscleGroups[groupIndex];
            final updatedExercises = List<WorkoutExercise>.from(group.exercises);
            
            final generatedSets = List.generate(sets, (_) => ExerciseSet(
              id: const Uuid().v4(), 
              reps: reps, 
              weight: weight,
            ));

            updatedExercises.add(WorkoutExercise(
              id: const Uuid().v4(),
              name: name,
              sets: generatedSets,
            ));
            _muscleGroups[groupIndex] = group.copyWith(exercises: updatedExercises);
          });
        },
      ),
    );
  }

  void _addSet(int groupIndex, int exerciseIndex) {
    setState(() {
      final group = _muscleGroups[groupIndex];
      final exercise = group.exercises[exerciseIndex];
      final updatedSets = List<ExerciseSet>.from(exercise.sets);
      
      // Copy last set values if possible
      int reps = 10;
      double? weight;
      if (updatedSets.isNotEmpty) {
        reps = updatedSets.last.reps;
        weight = updatedSets.last.weight;
      }
      
      updatedSets.add(ExerciseSet(id: const Uuid().v4(), reps: reps, weight: weight));
      
      final updatedExercises = List<WorkoutExercise>.from(group.exercises);
      updatedExercises[exerciseIndex] = exercise.copyWith(sets: updatedSets);
      
      _muscleGroups[groupIndex] = group.copyWith(exercises: updatedExercises);
    });
  }
  
  void _updateSet(int groupIndex, int exerciseIndex, int setIndex, {int? reps, double? weight, bool? isCompleted}) {
    setState(() {
      final group = _muscleGroups[groupIndex];
      final exercise = group.exercises[exerciseIndex];
      final updatedSets = List<ExerciseSet>.from(exercise.sets);
      
      updatedSets[setIndex] = updatedSets[setIndex].copyWith(
        reps: reps,
        weight: weight,
        isCompleted: isCompleted,
      );
      
      final updatedExercises = List<WorkoutExercise>.from(group.exercises);
      updatedExercises[exerciseIndex] = exercise.copyWith(sets: updatedSets);
      
      _muscleGroups[groupIndex] = group.copyWith(exercises: updatedExercises);
    });
  }

  void _removeSet(int groupIndex, int exerciseIndex, int setIndex) {
    setState(() {
      final group = _muscleGroups[groupIndex];
      final exercise = group.exercises[exerciseIndex];
      final updatedSets = List<ExerciseSet>.from(exercise.sets);
      
      updatedSets.removeAt(setIndex);
      
      final updatedExercises = List<WorkoutExercise>.from(group.exercises);
      updatedExercises[exerciseIndex] = exercise.copyWith(sets: updatedSets);
      
      _muscleGroups[groupIndex] = group.copyWith(exercises: updatedExercises);
    });
  }
  
  void _removeExercise(int groupIndex, int exerciseIndex) {
    setState(() {
      final group = _muscleGroups[groupIndex];
      final updatedExercises = List<WorkoutExercise>.from(group.exercises);
      updatedExercises.removeAt(exerciseIndex);
      _muscleGroups[groupIndex] = group.copyWith(exercises: updatedExercises);
    });
  }
  
  void _removeMuscleGroup(int groupIndex) {
    setState(() {
      _muscleGroups.removeAt(groupIndex);
    });
  }

  Future<void> _showAddDialog({required String title, required String hint, String? initialValue, required Function(String) onSave}) async {
    final controller = TextEditingController(text: initialValue);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundDarkGreen,
        title: Text(title, style: GoogleFonts.outfit(color: AppColors.textLight)),
        content: TextField(
          controller: controller,
          style: GoogleFonts.outfit(color: AppColors.textLight),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(color: AppColors.textMuted),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryNeon)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryNeon)),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.outfit(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onSave(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: Text('Adicionar', style: GoogleFonts.outfit(color: AppColors.primaryNeon, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundDarkGreen,
        title: Text('Excluir Treino?', style: GoogleFonts.outfit(color: AppColors.textLight)),
        content: Text('Esta ação não pode ser desfeita e excluirá o treino do seu diário.', style: GoogleFonts.outfit(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancelar', style: GoogleFonts.outfit(color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Excluir', style: GoogleFonts.outfit(color: AppColors.error, fontWeight: FontWeight.bold))),
        ],
      )
    );

    if (confirm == true && mounted) {
      await context.read<StrengthWorkoutProvider>().deleteWorkout(widget.template!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _saveWorkout() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dê um nome ao treino')));
      return;
    }
    
    if (_muscleGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adicione pelo menos um grupo muscular')));
      return;
    }

    setState(() => _isSaving = true);
    
    final workout = StrengthWorkout(
      id: (widget.template != null && widget.isEditing) ? widget.template!.id : const Uuid().v4(),
      name: _nameController.text.trim(),
      date: _selectedDate,
      notes: _notesController.text.trim(),
      muscleGroups: _muscleGroups,
    );

    await context.read<StrengthWorkoutProvider>().saveWorkout(workout);
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Novo Treino de Força',
          style: GoogleFonts.outfit(color: AppColors.textLight, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (widget.template != null && widget.isEditing)
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
              onPressed: _saveWorkout,
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
            // Header: Name and Date
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'Nome do Treino (ex: Treino A)',
                      hintStyle: GoogleFonts.outfit(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const Divider(color: AppColors.cardBorder),
                  InkWell(
                    onTap: _selectDate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.calendar, color: AppColors.primaryNeon, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            dateFormat,
                            style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(color: AppColors.cardBorder),
                  TextField(
                    controller: _notesController,
                    style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 14),
                    maxLines: 2,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Observações do treino (opcional)',
                      hintStyle: GoogleFonts.outfit(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Muscle Groups List
            ..._muscleGroups.asMap().entries.map((entry) {
              int gIndex = entry.key;
              WorkoutMuscleGroup group = entry.value;
              return _buildMuscleGroupSection(gIndex, group);
            }),
            
            const SizedBox(height: 16),
            
            // Add Muscle Group Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addMuscleGroup,
                icon: const Icon(LucideIcons.plusCircle, color: AppColors.primaryNeon),
                label: Text('Adicionar Grupo Muscular', style: GoogleFonts.outfit(color: AppColors.textLight)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: AppColors.primaryNeon.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 48), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildMuscleGroupSection(int groupIndex, WorkoutMuscleGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _showAddDialog(
                      title: 'Editar Grupo Muscular',
                      hint: 'Ex: Peito, Costas, Pernas',
                      initialValue: group.name,
                      onSave: (newName) {
                        setState(() {
                          _muscleGroups[groupIndex] = group.copyWith(name: newName);
                        });
                      },
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        group.name.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: AppColors.primaryNeon,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(LucideIcons.edit2, color: AppColors.primaryNeon, size: 14),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.trash2, color: AppColors.error, size: 18),
                onPressed: () => _removeMuscleGroup(groupIndex),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Exercises
          ...group.exercises.asMap().entries.map((exEntry) {
            return _buildExerciseCard(groupIndex, exEntry.key, exEntry.value);
          }),
          
          // Add Exercise Button (Small)
          TextButton.icon(
            onPressed: () => _addExercise(groupIndex),
            icon: const Icon(LucideIcons.plus, size: 16, color: AppColors.textLight),
            label: Text('Adicionar Exercício para ${group.name}', style: GoogleFonts.outfit(color: AppColors.textLight)),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(int groupIndex, int exerciseIndex, WorkoutExercise exercise) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _showAddDialog(
                      title: 'Editar Exercício',
                      hint: 'Ex: Supino Reto',
                      initialValue: exercise.name,
                      onSave: (newName) {
                        setState(() {
                          final group = _muscleGroups[groupIndex];
                          final updatedExercises = List<WorkoutExercise>.from(group.exercises);
                          updatedExercises[exerciseIndex] = exercise.copyWith(name: newName);
                          _muscleGroups[groupIndex] = group.copyWith(exercises: updatedExercises);
                        });
                      },
                    );
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          exercise.name,
                          style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(LucideIcons.edit2, color: AppColors.textMuted, size: 14),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x, color: AppColors.textMuted, size: 18),
                onPressed: () => _removeExercise(groupIndex, exerciseIndex),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Header Row for Sets
          Row(
            children: [
              const SizedBox(width: 32, child: Center(child: Text('Série', style: TextStyle(color: AppColors.textMuted, fontSize: 12)))),
              SizedBox(width: 60, child: Center(child: Text('Reps', style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12)))),
              const SizedBox(width: 12),
              Expanded(child: Center(child: Text('Kg', style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12)))),
              const SizedBox(width: 40), // For checkbox space
            ],
          ),
          const SizedBox(height: 8),
          
          // Sets List
          ...exercise.sets.asMap().entries.map((setEntry) {
            return _buildSetRow(groupIndex, exerciseIndex, setEntry.key, setEntry.value);
          }),
          
          const SizedBox(height: 8),
          // Add Set Button
          Center(
            child: TextButton(
              onPressed: () => _addSet(groupIndex, exerciseIndex),
              child: Text('+ Adicionar Série', style: GoogleFonts.outfit(color: AppColors.primaryNeon, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetRow(int groupIndex, int exerciseIndex, int setIndex, ExerciseSet exerciseSet) {
    // We use isolated controllers internally so they don't lose focus on digit type
    return Dismissible(
      key: Key(exerciseSet.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.error.withValues(alpha: 0.8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(LucideIcons.trash2, color: Colors.white),
      ),
      onDismissed: (_) => _removeSet(groupIndex, exerciseIndex, setIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        color: exerciseSet.isCompleted ? AppColors.primaryNeon.withValues(alpha: 0.1) : Colors.transparent,
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Center(
                child: Text('${setIndex + 1}', style: GoogleFonts.outfit(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(
              width: 60,
              child: Container(
                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(8)),
                child: TextFormField(
                  initialValue: exerciseSet.reps.toString(),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: AppColors.textLight, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                  onChanged: (val) {
                    final reps = int.tryParse(val);
                    if (reps != null) {
                      _updateSet(groupIndex, exerciseIndex, setIndex, reps: reps);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(8)),
                child: TextFormField(
                  initialValue: exerciseSet.weight?.toString() ?? '',
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: AppColors.textLight, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(hintText: '-', border: InputBorder.none, contentPadding: EdgeInsets.zero),
                  onChanged: (val) {
                    final weight = double.tryParse(val);
                    _updateSet(groupIndex, exerciseIndex, setIndex, weight: weight);
                  },
                ),
              ),
            ),
            SizedBox(
              width: 48,
              child: IconButton(
                icon: Icon(
                  exerciseSet.isCompleted ? LucideIcons.checkSquare : LucideIcons.square,
                  color: exerciseSet.isCompleted ? AppColors.primaryNeon : AppColors.textMuted,
                ),
                onPressed: () {
                  _updateSet(groupIndex, exerciseIndex, setIndex, isCompleted: !exerciseSet.isCompleted);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulkExerciseDialog extends StatefulWidget {
  final String groupName;
  final Function(String name, int sets, int reps, double? weight) onSave;

  const _BulkExerciseDialog({required this.groupName, required this.onSave});

  @override
  State<_BulkExerciseDialog> createState() => _BulkExerciseDialogState();
}

class _BulkExerciseDialogState extends State<_BulkExerciseDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _setsController = TextEditingController(text: '3');
  final TextEditingController _repsController = TextEditingController(text: '10');
  final TextEditingController _weightController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundDarkGreen,
      title: Text('Adicionar à ${widget.groupName}', style: GoogleFonts.outfit(color: AppColors.textLight)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              style: GoogleFonts.outfit(color: AppColors.textLight),
              decoration: InputDecoration(
                labelText: 'Nome do Exercício',
                labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryNeon)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryNeon)),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _setsController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.outfit(color: AppColors.textLight),
                    decoration: InputDecoration(
                      labelText: 'Séries',
                      labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryNeon)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryNeon)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _repsController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.outfit(color: AppColors.textLight),
                    decoration: InputDecoration(
                      labelText: 'Repetições',
                      labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryNeon)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryNeon)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.outfit(color: AppColors.textLight),
                    decoration: InputDecoration(
                      labelText: 'Kg (Opcional)',
                      labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryNeon)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryNeon)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: GoogleFonts.outfit(color: AppColors.textMuted)),
        ),
        TextButton(
          onPressed: () {
            if (_nameController.text.trim().isNotEmpty) {
              final sets = int.tryParse(_setsController.text) ?? 1;
              final reps = int.tryParse(_repsController.text) ?? 10;
              final weight = double.tryParse(_weightController.text);
              widget.onSave(_nameController.text.trim(), sets, reps, weight);
              Navigator.pop(context);
            }
          },
          child: Text('Adicionar', style: GoogleFonts.outfit(color: AppColors.primaryNeon, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
