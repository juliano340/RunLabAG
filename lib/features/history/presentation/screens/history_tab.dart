import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/services/database_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'run_detail_screen.dart';
import '../../../../core/utils/time_utils.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final DatabaseService _dbService = DatabaseService();
  List<RunModel> _runs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final runs = await _dbService.getHistory();
    setState(() {
      _runs = runs;
      _isLoading = false;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int seconds) {
    return TimeUtils.formatDuration(seconds);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Histórico de Atividades',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryNeon))
                  : _runs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.history, size: 64, color: AppColors.textMuted.withValues(alpha: 0.3)),
                              const SizedBox(height: 16),
                              Text(
                                'Nenhuma atividade registrada ainda.',
                                style: GoogleFonts.outfit(
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? AppColors.textMuted 
                                      : AppColors.textMutedDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Hora de queimar o asfalto!',
                                style: GoogleFonts.outfit(color: AppColors.primaryNeon, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _runs.length,
                          itemBuilder: (context, index) {
                            final run = _runs[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RunDetailScreen(run: run),
                                    ),
                                  ).then((_) => _loadHistory());
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: GlassContainer(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).brightness == Brightness.dark 
                                                ? AppColors.cardBorder.withValues(alpha: 0.3) 
                                                : AppColors.borderLight,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(LucideIcons.mapPin, color: AppColors.primaryNeon),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Corrida de ${run.distanceKm.toStringAsFixed(2)} km',
                                              style: GoogleFonts.outfit(
                                                color: Theme.of(context).colorScheme.onSurface,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${_formatDate(run.date)} • ${_formatDuration(run.durationSeconds)}',
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
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                             run.pace,
                                            style: GoogleFonts.outfit(
                                              color: AppColors.primaryNeonLight,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '/km',
                                            style: GoogleFonts.outfit(
                                              color: Theme.of(context).brightness == Brightness.dark 
                                                  ? AppColors.textMuted 
                                                  : AppColors.textMutedDark,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
