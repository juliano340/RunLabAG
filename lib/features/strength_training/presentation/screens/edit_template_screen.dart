import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../domain/models/workout_block.dart';
import '../providers/strength_workout_provider.dart';

class EditTemplateScreen extends StatefulWidget {
  final StrengthWorkoutTemplate template;

  const EditTemplateScreen({super.key, required this.template});

  @override
  State<EditTemplateScreen> createState() => _EditTemplateScreenState();
}

class _EditTemplateScreenState extends State<EditTemplateScreen> {
  late TextEditingController _nameController;
  late List<TemplateItem> _items;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template.name);
    _items = List.from(widget.template.items);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addBlock() {
    final provider = context.read<StrengthWorkoutProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundDarkGreen,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Escolha um Bloco',
                style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (provider.blocks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Nenhum bloco criado ainda.', style: GoogleFonts.outfit(color: AppColors.textMuted)),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: provider.blocks.length,
                    itemBuilder: (context, index) {
                      final block = provider.blocks[index];
                      return ListTile(
                        leading: const Icon(LucideIcons.box, color: AppColors.primaryNeon),
                        title: Text(block.name, style: const TextStyle(color: AppColors.textLight)),
                        subtitle: Text('${block.exercises.length} exercícios', style: const TextStyle(color: AppColors.textMuted)),
                        onTap: () {
                          setState(() {
                            _items.add(TemplateItem(
                              id: const Uuid().v4(),
                              type: TemplateItemType.block,
                              itemId: block.id,
                              orderIndex: _items.length,
                            ));
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dê um nome ao template')));
      return;
    }

    setState(() => _isSaving = true);
    
    final updatedTemplate = StrengthWorkoutTemplate(
      id: widget.template.id,
      name: _nameController.text.trim(),
      items: _items,
    );

    await context.read<StrengthWorkoutProvider>().saveTemplate(updatedTemplate);
    
    if (mounted) {
      Navigator.pop(context);
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
          widget.template.items.isEmpty ? 'Novo Template' : 'Editar Template',
          style: GoogleFonts.outfit(color: AppColors.textLight, fontWeight: FontWeight.bold),
        ),
        actions: [
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
              child: TextField(
                controller: _nameController,
                style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 20, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Nome do Template (ex: Treino A)',
                  hintStyle: GoogleFonts.outfit(color: AppColors.textMuted.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'COMPOSIÇÃO DO TREINO',
              style: GoogleFonts.outfit(
                color: AppColors.primaryNeon,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            
            if (_items.isEmpty)
              _buildEmptyComposition()
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (oldIndex < newIndex) newIndex -= 1;
                    final item = _items.removeAt(oldIndex);
                    _items.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Padding(
                    key: ValueKey(item.id),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildItemTile(index, item),
                  );
                },
              ),
            
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addBlock,
                icon: const Icon(LucideIcons.packagePlus, color: AppColors.primaryNeon),
                label: Text('Adicionar Bloco Reutilizável', style: GoogleFonts.outfit(color: AppColors.textLight)),
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

  Widget _buildEmptyComposition() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(LucideIcons.layout, color: AppColors.textMuted.withValues(alpha: 0.3), size: 48),
            const SizedBox(height: 12),
            Text(
              'Template sem conteúdo',
              style: GoogleFonts.outfit(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(int index, TemplateItem item) {
    if (item.type == TemplateItemType.block) {
      final provider = context.watch<StrengthWorkoutProvider>();
      final block = provider.blocks.firstWhere((b) => b.id == item.itemId, orElse: () => WorkoutBlock(id: '', name: 'Bloco Excluído'));
      
      return GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(LucideIcons.gripVertical, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 12),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryNeon.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.box, color: AppColors.primaryNeon, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    block.name,
                    style: GoogleFonts.outfit(color: AppColors.textLight, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Bloco: ${block.exercises.length} exercícios',
                    style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.trash2, color: AppColors.error, size: 18),
              onPressed: () {
                setState(() => _items.removeAt(index));
              },
            ),
          ],
        ),
      );
    }
    return const SizedBox();
  }
}
