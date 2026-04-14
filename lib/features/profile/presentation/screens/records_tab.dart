import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/utils/time_utils.dart';

class RecordsTab extends StatefulWidget {
  const RecordsTab({super.key});

  @override
  State<RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<RecordsTab> {
  final DatabaseService _dbService = DatabaseService();
  Map<String, dynamic>? _records;
  List<double> _monitoredDistances = [];
  List<String> _earnedAchievementIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final monitored = await _dbService.getMonitoredDistances();
    final records = await _dbService.getPersonalRecords();
    final earned = await _dbService.getEarnedAchievements();

    if (mounted) {
      setState(() {
        _monitoredDistances = monitored;
        _records = records;
        _earnedAchievementIds = earned.map((e) => e['id'] as String).toList();
        _isLoading = false;
      });
    }
  }

  String _formatTime(double? seconds) {
    if (seconds == null) return '--:--';
    return TimeUtils.formatDuration(seconds.toInt());
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Nenhum registro';
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Hoje';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showRecordHistory(String category, String label) async {
    final history = await _dbService.getRecordHistory(category);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildHistorySheet(
        title: 'Evolução: $label',
        subtitle: 'Acompanhe seu progresso histórico',
        icon: LucideIcons.trendingUp,
        content: history.isEmpty
            ? Center(
                child: Text(
                  'Sem histórico para esta categoria.',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : ListView.builder(
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
                  final bool isLast = index == history.length - 1;
                  final double improvement = item['improvement'] ?? 0.0;
                  return _buildTimelineItem(
                    index: index,
                    isLast: isLast,
                    title: _formatTime((item['time'] as double)),
                    subtitle: _formatDate(item['date']),
                    interval: item['interval'] as String?,
                    improvement: improvement > 0 ? '-${_formatTime(improvement)}' : null,
                  );
                },
              ),
      ),
    );
  }

  void _showLongestHistory() async {
    final history = await _dbService.getLongestDistanceHistory();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildHistorySheet(
        title: 'Recordes de Distância',
        subtitle: 'Marcos de superação de quilometragem',
        icon: LucideIcons.map,
        content: history.isEmpty
            ? Center(
                child: Text(
                  'Sem histórico de distância.',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : ListView.builder(
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
                  final bool isLast = index == history.length - 1;
                  final double improvement = item['improvement'] ?? 0.0;
                  return _buildTimelineItem(
                    index: index,
                    isLast: isLast,
                    title: '${(item['value'] as double).toStringAsFixed(2)} km',
                    subtitle: _formatDate(item['date']),
                    improvement: improvement > 0 ? '+${improvement.toStringAsFixed(2)} km' : null,
                    isPositive: true,
                  );
                },
              ),
      ),
    );
  }

  Widget _buildHistorySheet({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget content,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(icon, color: cs.primary),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: cs.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: GoogleFonts.outfit(color: cs.onSurfaceVariant)),
          const SizedBox(height: 24),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required int index,
    required bool isLast,
    required String title,
    required String subtitle,
    String? interval,
    String? improvement,
    bool isPositive = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: index == 0 ? cs.primary : cs.outline.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  boxShadow: index == 0
                      ? [BoxShadow(color: cs.primary.withValues(alpha: 0.4), blurRadius: 8)]
                      : null,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: cs.outline.withValues(alpha: 0.2)),
                ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          color: index == 0 ? cs.primary : cs.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (improvement != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isPositive ? Colors.blue : cs.primary).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            improvement,
                            style: GoogleFonts.outfit(
                              color: isPositive ? Colors.blueAccent : cs.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (interval != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      interval,
                      style: GoogleFonts.outfit(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _manageDistances() async {
    final TextEditingController controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final cs = Theme.of(context).colorScheme;
          return AlertDialog(
            backgroundColor: cs.surface,
            title: Text(
              'Monitorar Distâncias',
              style: GoogleFonts.outfit(color: cs.onSurface),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: cs.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Nova distância (km)',
                    labelStyle: TextStyle(color: cs.onSurfaceVariant),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: cs.outline),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  children: _monitoredDistances
                      .map(
                        (dist) => Chip(
                          backgroundColor: cs.primaryContainer,
                          label: Text(
                            '${dist.toStringAsFixed(1)}k',
                            style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold),
                          ),
                          onDeleted: () async {
                            await _dbService.removeMonitoredDistance(dist);
                            final updated = await _dbService.getMonitoredDistances();
                            setDialogState(() => _monitoredDistances = updated);
                            setState(() {});
                          },
                          deleteIconColor: cs.onPrimaryContainer,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Fechar', style: TextStyle(color: cs.onSurfaceVariant)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                ),
                onPressed: () async {
                  final dist = double.tryParse(controller.text);
                  if (dist != null && dist > 0) {
                    await _dbService.addMonitoredDistance(dist);
                    final updated = await _dbService.getMonitoredDistances();
                    setDialogState(() {
                      _monitoredDistances = updated;
                      controller.clear();
                    });
                    setState(() {});
                  }
                },
                child: const Text('Adicionar'),
              ),
            ],
          );
        },
      ),
    );
    _loadData();
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    final achievements = [
      {'id': 'first_run', 'title': 'Primeiro Passo', 'desc': 'Complete sua primeira corrida', 'icon': LucideIcons.footprints},
      {'id': 'night_owl', 'title': 'Coruja Noturna', 'desc': 'Corra após as 20h', 'icon': LucideIcons.moon},
      {'id': 'finisher_5k', 'title': 'Finalizador 5K', 'desc': 'Corra 5 quilômetros em uma sessão', 'icon': LucideIcons.medal},
      {'id': 'master_10k', 'title': 'Mestre 10K', 'desc': 'Corra 10 quilômetros em uma sessão', 'icon': LucideIcons.trophy},
      {'id': 'marathon_training', 'title': 'Treino de Maratona', 'desc': 'Corra 100km de distância total', 'icon': LucideIcons.target},
      {'id': 'speed_demon', 'title': 'Demônio da Velocidade', 'desc': 'Ritmo abaixo de 4:30/km por 1km', 'icon': LucideIcons.zap},
    ];

    return SafeArea(
      child: SingleChildScrollView(
        key: const PageStorageKey('records_scroll'),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recordes Pessoais',
                        style: GoogleFonts.outfit(
                          color: cs.onSurface,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Seu histórico de glórias',
                        style: GoogleFonts.outfit(color: cs.onSurfaceVariant, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildAchievementCountBadge(cs),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(cs, LucideIcons.trophy, 'Melhores Marcas'),
                TextButton.icon(
                  key: const ValueKey('btn_manage_distances'),
                  onPressed: _manageDistances,
                  icon: const Icon(LucideIcons.settings, size: 14),
                  label: Text('Gerenciar', style: GoogleFonts.outfit(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: cs.primary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildBestsGrid(cs),
            const SizedBox(height: 32),
            _buildSectionHeader(cs, LucideIcons.map, 'Superação de Limites'),
            const SizedBox(height: 16),
            _buildLongestRunCard(cs),
            const SizedBox(height: 40),
            _buildSectionHeader(cs, LucideIcons.medal, 'Conquistas Desbloqueadas'),
            const SizedBox(height: 16),
            _buildAchievementsList(cs, achievements),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementCountBadge(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.award, color: cs.onPrimaryContainer, size: 18),
          const SizedBox(width: 8),
          Text(
            _earnedAchievementIds.length.toString(),
            style: GoogleFonts.outfit(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ColorScheme cs, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: cs.primary, size: 20),
        const SizedBox(width: 10),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.outfit(
            color: cs.onSurfaceVariant,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildBestsGrid(ColorScheme cs) {
    final bests = _records?['bests'] as Map<String, dynamic>?;
    if (bests == null) return const SizedBox.shrink();

    return GridView.builder(
      key: const ValueKey('records_bests_grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.15,
      ),
      itemCount: _monitoredDistances.length,
      itemBuilder: (context, index) {
        final dist = _monitoredDistances[index];
        final key = dist == 21.0975
            ? '21km'
            : dist == 42.195
                ? '42km'
                : '${dist.toStringAsFixed(dist == dist.toInt() ? 0 : 1)}km';
        final data = bests[key];

        return _buildBestCard(
          cs,
          dist == 21.0975
              ? 'Meia Maratona'
              : (dist == 42.195 ? 'Maratona' : '${dist.toStringAsFixed(dist == dist.toInt() ? 0 : 1)} km'),
          _formatTime(data?['time']),
          _formatDate(data?['date']),
          interval: data?['interval'],
          onTap: () => _showRecordHistory(key, '${dist.toStringAsFixed(1)} km'),
        );
      },
    );
  }

  Widget _buildBestCard(
    ColorScheme cs,
    String label,
    String time,
    String date, {
    String? interval,
    VoidCallback? onTap,
  }) {
    final bool hasData = time != '--:--';
    return GlassContainer(
      onTap: hasData ? onTap : null,
      padding: const EdgeInsets.all(16),
      hasNeonBorder: hasData,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.outfit(color: cs.onSurfaceVariant, fontSize: 14)),
              if (hasData) Icon(LucideIcons.chevronRight, color: cs.onSurfaceVariant, size: 14),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              time,
              style: GoogleFonts.outfit(
                color: hasData ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.4),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (hasData) ...[
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  if (interval != null) ...[
                    Text(
                      interval,
                      style: GoogleFonts.outfit(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ' • ',
                      style: GoogleFonts.outfit(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                  Text(
                    date,
                    style: GoogleFonts.outfit(color: cs.onSurfaceVariant, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLongestRunCard(ColorScheme cs) {
    final longest = _records?['longestDistance'] as Map<String, dynamic>?;
    final double value = (longest?['value'] ?? 0.0);
    final bool hasData = value > 0;

    return GlassContainer(
      key: const ValueKey('records_longest_run_card'),
      onTap: hasData ? _showLongestHistory : null,
      padding: const EdgeInsets.all(20),
      hasNeonBorder: true,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.map, color: cs.onPrimaryContainer, size: 30),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Maior Distância',
                      style: GoogleFonts.outfit(color: cs.onSurfaceVariant, fontSize: 14),
                    ),
                    if (hasData)
                      Icon(LucideIcons.chevronRight, color: cs.onSurfaceVariant, size: 16),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${value.toStringAsFixed(2)} km',
                  style: GoogleFonts.outfit(
                    color: cs.onSurface,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (hasData)
                  Text(
                    'Registrado em ${_formatDate(longest?['date'])}',
                    style: GoogleFonts.outfit(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsList(ColorScheme cs, List<Map<String, dynamic>> allAchievements) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: allAchievements.length,
      itemBuilder: (context, index) {
        final badge = allAchievements[index];
        final bool earned = _earnedAchievementIds.contains(badge['id']);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            hasNeonBorder: false,
            child: Row(
              children: [
                Icon(
                  badge['icon'] as IconData,
                  size: 32,
                  color: earned ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.25),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        badge['title'] as String,
                        style: GoogleFonts.outfit(
                          color: earned ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.5),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        badge['desc'] as String,
                        style: GoogleFonts.outfit(
                          color: earned
                              ? cs.onSurfaceVariant
                              : cs.onSurfaceVariant.withValues(alpha: 0.35),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (earned) Icon(LucideIcons.checkCircle2, color: cs.primary, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
