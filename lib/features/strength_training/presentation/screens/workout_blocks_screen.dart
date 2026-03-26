import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../domain/models/workout_block.dart';
import '../../domain/models/strength_workout.dart';
import '../providers/strength_workout_provider.dart';
import 'edit_block_screen.dart';
import 'edit_template_screen.dart';
import 'new_workout_screen.dart';

class WorkoutBlocksScreen extends StatefulWidget {
  const WorkoutBlocksScreen({super.key});

  @override
  State<WorkoutBlocksScreen> createState() => _WorkoutBlocksScreenState();
}

class _WorkoutBlocksScreenState extends State<WorkoutBlocksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textLight),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Minha Biblioteca',
          style: GoogleFonts.outfit(
            color: AppColors.textLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryNeon,
          labelColor: AppColors.primaryNeon,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(text: 'Blocos'),
            Tab(text: 'Templates'),
          ],
        ),
      ),
      body: Consumer<StrengthWorkoutProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryNeon));
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildBlocksTab(context, provider),
              _buildTemplatesTab(context, provider),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryNeon,
        onPressed: () {
          if (_tabController.index == 0) {
            _createNewBlock(context);
          } else {
            _createNewTemplate(context);
          }
        },
        child: const Icon(LucideIcons.plus, color: Colors.black),
      ),
    );
  }

  Widget _buildBlocksTab(BuildContext context, StrengthWorkoutProvider provider) {
    final blocks = provider.blocks;

    if (blocks.isEmpty) {
      return _buildEmptyState(
        context,
        icon: LucideIcons.package,
        title: 'Sem Blocos',
        subtitle: 'Crie pequenos módulos de exercícios (ex: "Peito") para reutilizar.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: blocks.length,
      itemBuilder: (context, index) {
        final block = blocks[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EditBlockScreen(block: block)),
              );
            },
            child: GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primaryNeon.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.box, color: AppColors.primaryNeon),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          block.name,
                          style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${block.exercises.length} exercícios',
                          style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(LucideIcons.chevronRight, color: AppColors.textMuted, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTemplatesTab(BuildContext context, StrengthWorkoutProvider provider) {
    final templates = provider.templates;

    if (templates.isEmpty) {
      return _buildEmptyState(
        context,
        icon: LucideIcons.layout,
        title: 'Sem Templates',
        subtitle: 'Crie treinos completos (ex: "Treino A") combinando blocos.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryNeon.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(LucideIcons.clipboardList, color: AppColors.primaryNeon, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template.name,
                            style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${template.items.length} itens (blocos/exercícios)',
                            style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.settings, color: AppColors.textMuted, size: 20),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => EditTemplateScreen(template: template)),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNeon,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      final workout = provider.createWorkoutFromTemplate(template);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NewWorkoutScreen(templateSession: workout),
                        ),
                      );
                    },
                    icon: const Icon(LucideIcons.play, size: 16),
                    label: const Text('INICIAR TREINO', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _createNewBlock(BuildContext context) {
    _showNameDialog(context, 'Nome do Bloco', 'Ex: Peito, Costas', (name) {
      final newBlock = WorkoutBlock(id: const Uuid().v4(), name: name);
      Navigator.push(context, MaterialPageRoute(builder: (context) => EditBlockScreen(block: newBlock)));
    });
  }

  void _createNewTemplate(BuildContext context) {
    _showNameDialog(context, 'Nome do Template', 'Ex: Treino A, Full Body', (name) {
      final newTemplate = StrengthWorkoutTemplate(id: const Uuid().v4(), name: name);
      Navigator.push(context, MaterialPageRoute(builder: (context) => EditTemplateScreen(template: newTemplate)));
    });
  }

  void _showNameDialog(BuildContext context, String title, String hint, Function(String) onConfirm) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundDarkGreen,
        title: Text(title, style: GoogleFonts.outfit(color: AppColors.textLight)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textLight),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryNeon)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNeon),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                final name = controller.text.trim();
                Navigator.pop(context);
                onConfirm(name);
              }
            },
            child: const Text('Criar', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.textMuted.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: AppColors.textMuted.withValues(alpha: 0.7), fontSize: 14),
          ),
        ],
      ),
    );
  }
}
