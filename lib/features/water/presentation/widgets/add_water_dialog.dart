import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:runlabag/core/theme/app_colors.dart';
import 'package:runlabag/features/water/presentation/providers/water_provider.dart';

class AddWaterDialog extends StatefulWidget {
  const AddWaterDialog({super.key});

  @override
  State<AddWaterDialog> createState() => _AddWaterDialogState();
}

class _AddWaterDialogState extends State<AddWaterDialog> {
  final List<int> _quickPresets = [200, 250, 300, 500, 750];
  int _customAmount = 250;
  final TextEditingController _controller = TextEditingController(text: '250');

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.backgroundDarkGreen,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.primaryNeon.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.droplet, color: Colors.blueAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              'Adicionar Água',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // Grid de Presets
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: _quickPresets.map((amount) => _buildPresetButton(amount)).toList(),
            ),
            
            const SizedBox(height: 24),
            
            // Custom Input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Outra quantidade',
                        hintStyle: TextStyle(color: Colors.white24),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _customAmount = int.tryParse(val) ?? 0;
                        });
                      },
                    ),
                  ),
                  const Text('ml', style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNeon,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      if (_customAmount > 0) {
                        context.read<WaterProvider>().addWater(_customAmount);
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('ADICIONAR', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton(int amount) {
    bool isSelected = _customAmount == amount;
    return GestureDetector(
      onTap: () {
        setState(() {
          _customAmount = amount;
          _controller.text = amount.toString();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          '${amount}ml',
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textMuted,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
