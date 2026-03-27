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
  final StrengthWorkout? templateSession;
  final bool isEditing;

  const NewWorkoutScreen({
    super.key, 
    this.template, 
    this.templateSession,
    this.isEditing = false
  });

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
        // Clone the groups but reset sets if needed
        _muscleGroups = widget.template!.muscleGroups.map((g) => g.copyWith(
          id: const Uuid().v4(),
          exercises: g.exercises.map((e) => e.copyWith(
            id: const Uuid().v4(),
            sets: e.sets.map((s) => s.copyWith(id: const Uuid().v4(), isCompleted: false)).toList(),
          )).toList(),
        )).toList();
      }
    } else if (widget.templateSession != null) {
      _nameController.text = widget.templateSession!.name;
      _muscleGroups = List.from(widget.templateSession!.muscleGroups);
      _selectedDate = DateTime.now();
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
  
  Future<void> _removeExercise(int groupIndex, int exerciseIndex) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundDarkGreen,
        title: Text('Remover Exercício?', style: GoogleFonts.outfit(color: AppColors.textLight)),
        content: Text('Deseja realmente remover este exercício do treino?', style: GoogleFonts.outfit(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))),
        ],
      )
    );

    if (confirm == true) {
      setState(() {
        final group = _muscleGroups[groupIndex];
        final updatedExercises = List<WorkoutExercise>.from(group.exercises);
        updatedExercises.removeAt(exerciseIndex);
        _muscleGroups[groupIndex] = group.copyWith(exercises: updatedExercises);
      });
    }
  }
  
  Future<void> _removeMuscleGroup(int groupIndex) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundDarkGreen,
        title: Text('Remover Grupo?', style: GoogleFonts.outfit(color: AppColors.textLight)),
        content: Text('Deseja remover este grupo muscular e todos os seus exercícios?', style: GoogleFonts.outfit(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))),
        ],
      )
    );

    if (confirm == true) {
      setState(() {
        _muscleGroups.removeAt(groupIndex);
      });
    }
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

  void _completeExercise(int gIndex, int eIndex) {
    setState(() {
      final group = _muscleGroups[gIndex];
      final exercise = group.exercises[eIndex];
      
      // Determine if all are already completed
      final allCompleted = exercise.sets.isNotEmpty && exercise.sets.every((s) => s.isCompleted);
      
      // If all are completed, unmark all. Otherwise, mark all.
      final updatedSets = exercise.sets.map((s) => s.copyWith(isCompleted: !allCompleted)).toList();
      
      final updatedExercises = List<WorkoutExercise>.from(group.exercises);
      updatedExercises[eIndex] = exercise.copyWith(sets: updatedSets);
      _muscleGroups[gIndex] = group.copyWith(exercises: updatedExercises);
    });
  }

  void _completeGroup(int gIndex) {
    setState(() {
      final group = _muscleGroups[gIndex];
      
      // Determine if all sets in all exercises are already completed
      bool allGroupCompleted = true;
      for (var ex in group.exercises) {
        if (ex.sets.isEmpty || !ex.sets.every((s) => s.isCompleted)) {
          allGroupCompleted = false;
          break;
        }
      }
      
      // If all are completed, unmark all. Otherwise, mark all.
      final updatedExercises = group.exercises.map((e) => e.copyWith(
        sets: e.sets.map((s) => s.copyWith(isCompleted: !allGroupCompleted)).toList(),
      )).toList();
      
      _muscleGroups[gIndex] = group.copyWith(exercises: updatedExercises);
    });
  }

  double _getGroupProgress(int gIndex) {
    final group = _muscleGroups[gIndex];
    if (group.exercises.isEmpty) return 0;
    
    int totalSets = 0;
    int completedSets = 0;
    
    for (var ex in group.exercises) {
      totalSets += ex.sets.length;
      completedSets += ex.sets.where((s) => s.isCompleted).length;
    }
    
    return totalSets == 0 ? 0 : completedSets / totalSets;
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
    return _MuscleGroupSection(
      key: ValueKey('group_$groupIndex'),
      groupIndex: groupIndex,
      group: group,
      progress: _getGroupProgress(groupIndex),
      initialCollapsed: true, // Default to collapsed as before
      onCompleteGroup: _completeGroup,
      onRemoveGroup: _removeMuscleGroup,
      onRenameGroup: (index, newName) {
        setState(() {
          _muscleGroups[index] = _muscleGroups[index].copyWith(name: newName);
        });
      },
      onAddExercise: _addExercise,
      onCompleteExercise: _completeExercise,
      onRemoveExercise: _removeExercise,
      onAddSet: _addSet,
      onUpdateSet: _updateSet,
      onRemoveSet: _removeSet,
      showAddDialog: _showAddDialog,
    );
  }
}

class _MuscleGroupSection extends StatefulWidget {
  final int groupIndex;
  final WorkoutMuscleGroup group;
  final double progress;
  final bool initialCollapsed;
  final Function(int) onCompleteGroup;
  final Function(int) onRemoveGroup;
  final Function(int, String) onRenameGroup;
  final Function(int) onAddExercise;
  final Function(int, int) onCompleteExercise;
  final Function(int, int) onRemoveExercise;
  final Function(int, int) onAddSet;
  final Function(int, int, int, {int? reps, double? weight, bool? isCompleted}) onUpdateSet;
  final Function(int, int, int) onRemoveSet;
  final Function({required String title, required String hint, String? initialValue, required Function(String) onSave}) showAddDialog;

  const _MuscleGroupSection({
    super.key,
    required this.groupIndex,
    required this.group,
    required this.progress,
    required this.initialCollapsed,
    required this.onCompleteGroup,
    required this.onRemoveGroup,
    required this.onRenameGroup,
    required this.onAddExercise,
    required this.onCompleteExercise,
    required this.onRemoveExercise,
    required this.onAddSet,
    required this.onUpdateSet,
    required this.onRemoveSet,
    required this.showAddDialog,
  });

  @override
  State<_MuscleGroupSection> createState() => _MuscleGroupSectionState();
}

class _MuscleGroupSectionState extends State<_MuscleGroupSection> {
  late bool _isCollapsed;

  @override
  void initState() {
    super.initState();
    _isCollapsed = widget.initialCollapsed;
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.progress == 1.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  splashColor: AppColors.primaryNeon.withValues(alpha: 0.1),
                  highlightColor: AppColors.primaryNeon.withValues(alpha: 0.05),
                  onTap: () {
                    setState(() {
                      _isCollapsed = !_isCollapsed;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isCollapsed ? LucideIcons.chevronRight : LucideIcons.chevronDown,
                          color: isCompleted ? AppColors.primaryNeon.withValues(alpha: 0.5) : AppColors.textMuted,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.group.name.toUpperCase()} (${widget.group.exercises.length})',
                          style: GoogleFonts.outfit(
                            color: isCompleted ? AppColors.primaryNeon.withValues(alpha: 0.6) : AppColors.primaryNeon,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1.5,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Progress Circle
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  value: widget.progress,
                  strokeWidth: 2,
                  backgroundColor: AppColors.cardBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isCompleted ? AppColors.primaryNeon : AppColors.textMuted,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  isCompleted ? LucideIcons.undo2 : LucideIcons.checkCheck, 
                  color: isCompleted ? AppColors.textMuted : AppColors.primaryNeon, 
                  size: 18
                ),
                onPressed: () => widget.onCompleteGroup(widget.groupIndex),
                tooltip: isCompleted ? 'Desmarcar grupo' : 'Concluir grupo todo',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              if (!isCompleted) ...[
                IconButton(
                  icon: const Icon(LucideIcons.edit2, color: AppColors.primaryNeon, size: 14),
                  onPressed: () {
                    widget.showAddDialog(
                      title: 'Editar Grupo Muscular',
                      hint: 'Ex: Peito, Costas, Pernas',
                      initialValue: widget.group.name,
                      onSave: (newName) {
                        widget.onRenameGroup(widget.groupIndex, newName);
                      },
                    );
                  },
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.trash2, color: AppColors.error, size: 18),
                  onPressed: () => widget.onRemoveGroup(widget.groupIndex),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          
          // Exercises (Animated Expansion)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: !_isCollapsed ? RepaintBoundary(
              child: Column(
                children: [
                   ...widget.group.exercises.asMap().entries.map((exEntry) {
                    return _ExerciseCard(
                      groupIndex: widget.groupIndex,
                      exerciseIndex: exEntry.key,
                      exercise: exEntry.value,
                      onComplete: widget.onCompleteExercise,
                      onRemove: widget.onRemoveExercise,
                      onAddSet: widget.onAddSet,
                      onUpdateSet: widget.onUpdateSet,
                      onRemoveSet: widget.onRemoveSet,
                      showAddDialog: widget.showAddDialog,
                    );
                  }),
                  
                  // Add Exercise Button (Small)
                  TextButton.icon(
                    onPressed: () => widget.onAddExercise(widget.groupIndex),
                    icon: const Icon(LucideIcons.plus, size: 16, color: AppColors.textLight),
                    label: Text('Adicionar Exercício para ${widget.group.name}', style: GoogleFonts.outfit(color: AppColors.textLight)),
                  ),
                  
                  // Bottom Collapse Button
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isCollapsed = true;
                        });
                      },
                      icon: const Icon(LucideIcons.chevronUp, size: 14, color: AppColors.textMuted),
                      label: Text(
                        'RECOLHER ${widget.group.name.toUpperCase()}', 
                        style: GoogleFonts.outfit(
                          color: AppColors.textMuted, 
                          fontSize: 10, 
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2
                        )
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ) : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final int groupIndex;
  final int exerciseIndex;
  final WorkoutExercise exercise;
  final Function(int, int) onComplete;
  final Function(int, int) onRemove;
  final Function(int, int) onAddSet;
  final Function(int, int, int, {int? reps, double? weight, bool? isCompleted}) onUpdateSet;
  final Function(int, int, int) onRemoveSet;
  final Function({required String title, required String hint, String? initialValue, required Function(String) onSave}) showAddDialog;

  const _ExerciseCard({
    required this.groupIndex,
    required this.exerciseIndex,
    required this.exercise,
    required this.onComplete,
    required this.onRemove,
    required this.onAddSet,
    required this.onUpdateSet,
    required this.onRemoveSet,
    required this.showAddDialog,
  });

  @override
  Widget build(BuildContext context) {
    int totalSets = exercise.sets.length;
    int completedSets = exercise.sets.where((s) => s.isCompleted).length;
    double progress = totalSets == 0 ? 0 : completedSets / totalSets;
    bool isCompleted = progress == 1.0;

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      enableBlur: false, // Performance: Disable blur for repeating items
      backgroundColor: isCompleted 
        ? AppColors.primaryNeon.withValues(alpha: 0.05) 
        : AppColors.cardBackground.withValues(alpha: 0.1),
      borderColor: isCompleted 
        ? AppColors.primaryNeon.withValues(alpha: 0.3) 
        : AppColors.cardBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: isCompleted ? null : () {
                    showAddDialog(
                      title: 'Editar Exercício',
                      hint: 'Ex: Supino Reto',
                      initialValue: exercise.name,
                      onSave: (newName) {
                        // This callback is handled by the parent
                        onUpdateSet(groupIndex, exerciseIndex, -1, reps: null); // Hacky way to signal name update if needed, or pass another callback
                      },
                    );
                  },
                  child: Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 2,
                          backgroundColor: AppColors.cardBorder,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isCompleted ? AppColors.primaryNeon : AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          exercise.name,
                          style: GoogleFonts.outfit(
                            color: isCompleted ? AppColors.textLight.withValues(alpha: 0.7) : AppColors.textLight, 
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isCompleted ? LucideIcons.undo2 : LucideIcons.checkCheck, 
                      color: isCompleted ? AppColors.textMuted : AppColors.primaryNeon, 
                      size: 18
                    ),
                    onPressed: () => onComplete(groupIndex, exerciseIndex),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  if (!isCompleted)
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: AppColors.textMuted, size: 18),
                      onPressed: () => onRemove(groupIndex, exerciseIndex),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              const SizedBox(width: 32, child: Center(child: Text('Série', style: TextStyle(color: AppColors.textMuted, fontSize: 12)))),
              SizedBox(width: 60, child: Center(child: Text('Reps', style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12)))),
              const SizedBox(width: 12),
              Expanded(child: Center(child: Text('Kg', style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12)))),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 8),
          
          ...exercise.sets.asMap().entries.map((setEntry) {
            return _SetRow(
              key: ValueKey(setEntry.value.id),
              setIndex: setEntry.key,
              exerciseSet: setEntry.value,
              onUpdate: ({reps, weight, isCompleted}) {
                onUpdateSet(groupIndex, exerciseIndex, setEntry.key, reps: reps, weight: weight, isCompleted: isCompleted);
              },
              onRemove: () => onRemoveSet(groupIndex, exerciseIndex, setEntry.key),
            );
          }),
          
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => onAddSet(groupIndex, exerciseIndex),
              child: Text('+ Adicionar Série', style: GoogleFonts.outfit(color: AppColors.primaryNeon, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetRow extends StatefulWidget {
  final int setIndex;
  final ExerciseSet exerciseSet;
  final Function({int? reps, double? weight, bool? isCompleted}) onUpdate;
  final VoidCallback onRemove;

  const _SetRow({
    super.key,
    required this.setIndex,
    required this.exerciseSet,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late TextEditingController _repsController;
  late TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    _repsController = TextEditingController(text: widget.exerciseSet.reps.toString());
    _weightController = TextEditingController(text: widget.exerciseSet.weight?.toString() ?? '');
  }

  @override
  void didUpdateWidget(_SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update if not currently focused to avoid jumpy cursor
    if (widget.exerciseSet.reps.toString() != _repsController.text && !FocusScope.of(context).hasFocus) {
      _repsController.text = widget.exerciseSet.reps.toString();
    }
    if ((widget.exerciseSet.weight?.toString() ?? '') != _weightController.text && !FocusScope.of(context).hasFocus) {
      _weightController.text = widget.exerciseSet.weight?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(widget.exerciseSet.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.error.withValues(alpha: 0.8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(LucideIcons.trash2, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.backgroundDarkGreen,
            title: Text('Remover Série?', style: GoogleFonts.outfit(color: AppColors.textLight)),
            content: Text('Deseja realmente remover esta série?', style: GoogleFonts.outfit(color: AppColors.textMuted)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted))),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))),
            ],
          )
        );
      },
      onDismissed: (_) => widget.onRemove(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        color: widget.exerciseSet.isCompleted ? AppColors.primaryNeon.withValues(alpha: 0.1) : Colors.transparent,
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(LucideIcons.minusCircle, color: AppColors.error.withValues(alpha: 0.5), size: 16),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppColors.backgroundDarkGreen,
                      title: Text('Remover Série?', style: GoogleFonts.outfit(color: AppColors.textLight)),
                      content: Text('Deseja realmente remover esta série?', style: GoogleFonts.outfit(color: AppColors.textMuted)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted))),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))),
                      ],
                    )
                  );
                  if (confirm == true) {
                    widget.onRemove();
                  }
                },
              ),
            ),
            SizedBox(
              width: 20,
              child: Center(
                child: Text('${widget.setIndex + 1}', style: GoogleFonts.outfit(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(
              width: 60,
              child: Container(
                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(8)),
                child: TextFormField(
                  controller: _repsController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: AppColors.textLight, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                  onChanged: (val) {
                    final reps = int.tryParse(val);
                    if (reps != null) {
                      widget.onUpdate(reps: reps);
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
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: AppColors.textLight, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(hintText: '-', border: InputBorder.none, contentPadding: EdgeInsets.zero),
                  onChanged: (val) {
                    final weight = double.tryParse(val);
                    widget.onUpdate(weight: weight);
                  },
                ),
              ),
            ),
            SizedBox(
              width: 48,
              child: IconButton(
                icon: Icon(
                  widget.exerciseSet.isCompleted ? LucideIcons.checkSquare : LucideIcons.square,
                  color: widget.exerciseSet.isCompleted ? AppColors.primaryNeon : AppColors.textMuted,
                ),
                onPressed: () {
                  widget.onUpdate(isCompleted: !widget.exerciseSet.isCompleted);
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
