import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../core/services/recommendation_service.dart';
import 'run_detail_screen.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/runs_provider.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final DatabaseService _dbService = DatabaseService();
  List<RunModel> _allRuns = [];
  List<RunModel> _filteredRuns = [];
  bool _isLoading = true;
  int _selectedPeriodIndex = 0; // 0: Semana, 1: Mês
  final List<String> _periods = ['Semana', 'Mês'];

  UserProfile? _userProfile;
  double _currentPeriodGoal =
      20.0; // The historically-locked goal for the displayed period

  // Pagination State
  DateTime _referenceDate = DateTime.now();
  DateTime? _minDate;
  DateTime? _maxDate;
  RecommendationResult? _recommendation;

  RunsProvider? _runsProvider;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final runsProvider = Provider.of<RunsProvider>(context, listen: false);
    if (_runsProvider != runsProvider) {
      _runsProvider?.removeListener(_loadData);
      _runsProvider = runsProvider;
      _runsProvider!.addListener(_loadData);
    }
  }

  @override
  void dispose() {
    _runsProvider?.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    final runs = await _dbService.getRuns();
    final profile = await _dbService.getUserProfile();

    if (mounted) {
      DateTime? min;
      DateTime? max;
      if (runs.isNotEmpty) {
        min = runs.map((r) => r.date).reduce((a, b) => a.isBefore(b) ? a : b);
        max = runs.map((r) => r.date).reduce((a, b) => a.isAfter(b) ? a : b);
      }

      setState(() {
        _allRuns = runs;
        _userProfile = profile;
        _minDate = min;
        _maxDate = max;
      });
      await _filterData();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getPeriodId() {
    if (_selectedPeriodIndex == 0) {
      // Weekly
      final startOfWeek = _referenceDate.subtract(
        Duration(days: _referenceDate.weekday % 7),
      );
      // ISO week number-like ID: YYYY-WNN
      final dayOfYear = startOfWeek
          .difference(DateTime(startOfWeek.year, 1, 1))
          .inDays;
      final weekNum = (dayOfYear / 7).floor() + 1;
      return '${startOfWeek.year}-W${weekNum.toString().padLeft(2, '0')}';
    } else {
      // Monthly
      return '${_referenceDate.year}-${_referenceDate.month.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _filterData() async {
    final periodId = _getPeriodId();
    final goalType = _selectedPeriodIndex == 0 ? 'weekly' : 'monthly';
    final defaultGoal = _selectedPeriodIndex == 0
        ? (_userProfile?.weeklyGoal ?? 20.0)
        : (_userProfile?.monthlyGoal ?? 80.0);

    // Try to load an existing historical snapshot for this period
    double? historicalGoal = await _dbService.getGoalHistory(
      periodId,
      goalType,
    );

    if (historicalGoal == null) {
      // No snapshot yet — create one now to "freeze" the current goal to this period
      historicalGoal = defaultGoal;
      await _dbService.saveGoalHistory(periodId, goalType, defaultGoal);
    }

    if (_selectedPeriodIndex == 0) {
      // Week
      final startOfWeek = _referenceDate.subtract(
        Duration(days: _referenceDate.weekday % 7),
      );
      final start = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day,
      );
      final end = start.add(const Duration(days: 7));

      _filteredRuns = _allRuns
          .where(
            (run) =>
                run.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
                run.date.isBefore(end),
          )
          .toList();

      final now = DateTime.now();
      final currentWeekStart = now.subtract(Duration(days: now.weekday % 7));

      if (start.year == currentWeekStart.year &&
          start.month == currentWeekStart.month &&
          start.day == currentWeekStart.day &&
          _userProfile != null) {
        _recommendation = RecommendationService.calculateWeeklyRecommendation(
          profile: _userProfile!,
          runs: _filteredRuns, // current week only (already filtered above)
          monthRuns: _allRuns.where((r) {
            final cutoff = now.subtract(const Duration(days: 30));
            return r.date.isAfter(cutoff) &&
                r.date.isBefore(start); // exclude current week
          }).toList(),
          currentPeriodGoal: historicalGoal,
        );
      } else {
        _recommendation = null;
      }
    } else {
      // Month
      _recommendation = null;
      final startOfMonth = DateTime(
        _referenceDate.year,
        _referenceDate.month,
        1,
      );
      final nextMonth = DateTime(
        _referenceDate.year,
        _referenceDate.month + 1,
        1,
      );

      _filteredRuns = _allRuns
          .where(
            (run) =>
                run.date.isAfter(
                  startOfMonth.subtract(const Duration(seconds: 1)),
                ) &&
                run.date.isBefore(nextMonth),
          )
          .toList();
    }

    if (mounted) {
      setState(() => _currentPeriodGoal = historicalGoal!);
    }
  }

  bool _canGoPrevious() {
    if (_minDate == null) return false;

    // Calculate the start of the earliest possible period we should show
    // Usually we don't need to go before the first run ever recorded
    if (_selectedPeriodIndex == 0) {
      // Semana
      final startOfCurrentWeek = _referenceDate.subtract(
        Duration(days: _referenceDate.weekday % 7),
      );
      final start = DateTime(
        startOfCurrentWeek.year,
        startOfCurrentWeek.month,
        startOfCurrentWeek.day,
      );
      return _minDate!.isBefore(start);
    } else {
      // Mês
      final startOfCurrentMonth = DateTime(
        _referenceDate.year,
        _referenceDate.month,
        1,
      );
      return _minDate!.isBefore(startOfCurrentMonth);
    }
  }

  bool _canGoNext() {
    // We should ALWAYS be able to see the current week/month even if there's no data yet.
    final now = DateTime.now();
    DateTime effectiveMax = _maxDate == null || now.isAfter(_maxDate!)
        ? now
        : _maxDate!;

    if (_selectedPeriodIndex == 0) {
      // PROPOSAL: Allow one future week (+ 7 days) to see upcoming goals
      effectiveMax = effectiveMax.add(const Duration(days: 7));

      // Semana
      final startOfCurrentWeek = _referenceDate.subtract(
        Duration(days: _referenceDate.weekday % 7),
      );
      final endOfCurrentWeek = DateTime(
        startOfCurrentWeek.year,
        startOfCurrentWeek.month,
        startOfCurrentWeek.day,
      ).add(const Duration(days: 7));
      return effectiveMax.isAfter(
        endOfCurrentWeek.subtract(const Duration(seconds: 1)),
      );
    } else {
      // Mês
      final startOfNextMonth = DateTime(
        _referenceDate.year,
        _referenceDate.month + 1,
        1,
      );
      return effectiveMax.isAfter(
        startOfNextMonth.subtract(const Duration(seconds: 1)),
      );
    }
  }

  void _previousPeriod() {
    if (!_canGoPrevious()) return;
    setState(() {
      if (_selectedPeriodIndex == 0) {
        _referenceDate = _referenceDate.subtract(const Duration(days: 7));
      } else {
        _referenceDate = DateTime(
          _referenceDate.year,
          _referenceDate.month - 1,
          1,
        );
      }
    });
    _filterData();
  }

  void _nextPeriod() {
    if (!_canGoNext()) return;
    setState(() {
      if (_selectedPeriodIndex == 0) {
        _referenceDate = _referenceDate.add(const Duration(days: 7));
      } else {
        _referenceDate = DateTime(
          _referenceDate.year,
          _referenceDate.month + 1,
          1,
        );
      }
    });
    _filterData();
  }

  String _getPeriodTitle() {
    final months = [
      '',
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    final monthsShort = [
      '',
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];

    if (_selectedPeriodIndex == 0) {
      final startOfWeek = _referenceDate.subtract(
        Duration(days: _referenceDate.weekday % 7),
      );
      final endOfWeek = startOfWeek.add(const Duration(days: 6));

      if (startOfWeek.month == endOfWeek.month) {
        return '${startOfWeek.day} - ${endOfWeek.day} de ${months[startOfWeek.month]}';
      } else {
        return '${startOfWeek.day} ${monthsShort[startOfWeek.month]} - ${endOfWeek.day} ${monthsShort[endOfWeek.month]}';
      }
    } else {
      return '${months[_referenceDate.month]} ${_referenceDate.year}';
    }
  }

  String _formatDateShort(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Hoje';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  void _showGoalSettings() {
    final periodId = _getPeriodId();
    final goalType = _selectedPeriodIndex == 0 ? 'weekly' : 'monthly';
    final periodController = TextEditingController(
      text: _currentPeriodGoal.toStringAsFixed(1),
    );
    final TextEditingController globalController = TextEditingController(
      text: _selectedPeriodIndex == 0
          ? (_userProfile?.weeklyGoal.toStringAsFixed(1) ?? '20.0')
          : (_userProfile?.monthlyGoal.toStringAsFixed(1) ?? '80.0'),
    );

    showDialog(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          title: Text(
            'Configurar Meta',
            style: GoogleFonts.outfit(color: cs.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Per-period goal
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock_clock, color: cs.primary, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Meta deste período',
                          style: GoogleFonts.outfit(
                            color: cs.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Altera apenas este período. Não afeta o histórico.',
                      style: GoogleFonts.outfit(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: periodController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: cs.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Meta (km)',
                        labelStyle: TextStyle(color: cs.onSurfaceVariant),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: cs.outline),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Default / future goal
              TextField(
                controller: globalController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: 'Meta padrão futura (km)',
                  helperText: 'Aplicada a novos períodos',
                  helperStyle: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  labelStyle: TextStyle(color: cs.onSurfaceVariant),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: cs.outline),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CANCELAR',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: cs.primary),
              onPressed: () async {
                final newPeriodGoal =
                    double.tryParse(periodController.text) ??
                    _currentPeriodGoal;
                final newGlobalGoal =
                    double.tryParse(globalController.text) ??
                    (_userProfile?.weeklyGoal ?? 20.0);
                final navigator = Navigator.of(context);

                // Save per-period (historical) goal
                await _dbService.saveGoalHistory(
                  periodId,
                  goalType,
                  newPeriodGoal,
                );

                // Save global default for future periods
                if (_userProfile != null) {
                  final updatedProfile = UserProfile(
                    name: _userProfile!.name,
                    age: _userProfile!.age,
                    weight: _userProfile!.weight,
                    height: _userProfile!.height,
                    profilePicturePath: _userProfile!.profilePicturePath,
                    weeklyGoal: _selectedPeriodIndex == 0
                        ? newGlobalGoal
                        : _userProfile!.weeklyGoal,
                    monthlyGoal: _selectedPeriodIndex == 1
                        ? newGlobalGoal
                        : _userProfile!.monthlyGoal,
                    lastGoalUpdate: DateTime.now(),
                  );
                  await _dbService.saveUserProfile(updatedProfile);
                  if (mounted) setState(() => _userProfile = updatedProfile);
                }

                if (mounted) {
                  setState(() => _currentPeriodGoal = newPeriodGoal);
                  navigator.pop();
                }
              },
              child: Text(
                'SALVAR',
                style: TextStyle(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dashboard',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: _showGoalSettings,
                  icon: Icon(
                    LucideIcons.settings,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildPeriodSelector(),
          const SizedBox(height: 12),
          _buildPaginationHeader(),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryNeon,
                    ),
                  )
                : SingleChildScrollView(
                    key: const PageStorageKey('history_scroll'),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildAnalyticsSummary(),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              Text(
                                'Atividades',
                                style: GoogleFonts.outfit(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_filteredRuns.length} treinos',
                                style: GoogleFonts.outfit(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildActivitiesList(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 40,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: List.generate(_periods.length, (index) {
            final isSelected = _selectedPeriodIndex == index;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPeriodIndex = index;
                    _referenceDate = DateTime.now();
                  });
                  _filterData();
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cs.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: cs.primary.withValues(alpha: 0.3))
                        : null,
                  ),
                  child: Text(
                    _periods[index],
                    style: GoogleFonts.outfit(
                      color: isSelected ? cs.primary : cs.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildPaginationHeader() {
    final canPrev = _canGoPrevious();
    final canNext = _canGoNext();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: canPrev ? _previousPeriod : null,
            icon: Icon(
              LucideIcons.chevronLeft,
              color: canPrev
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
            ),
            visualDensity: VisualDensity.compact,
          ),
          Text(
            _getPeriodTitle(),
            style: GoogleFonts.outfit(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          IconButton(
            onPressed: canNext ? _nextPeriod : null,
            icon: Icon(
              LucideIcons.chevronRight,
              color: canNext
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSummary() {
    double totalKm = _filteredRuns.fold(0.0, (sum, r) => sum + r.distanceKm);
    int totalDur = _filteredRuns.fold(0, (sum, r) => sum + r.durationSeconds);
    int totalCal = _filteredRuns.fold(0, (sum, r) => sum + r.calories);
    double weightLossKg = totalCal / 7700.0;

    double goal = _currentPeriodGoal;
    double rawProgress = goal > 0 ? totalKm / goal : 0.0;
    double progress = rawProgress.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Row 1: Chart & Circle
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Desempenho',
                        style: GoogleFonts.outfit(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(height: 100, child: _buildBarChart()),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Meta',
                        style: GoogleFonts.outfit(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 70,
                            width: 70,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 8,
                              color: _getGoalColor(rawProgress),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          Text(
                            '${(rawProgress * 100).toInt()}%',
                            style: GoogleFonts.outfit(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : AppColors.textDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${totalKm.toStringAsFixed(1)} / ${goal.toInt()} km',
                        style: GoogleFonts.outfit(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row 2: Stats
          Row(
            children: [
              _buildSmallStat(
                'Duração',
                TimeUtils.formatDuration(totalDur),
                LucideIcons.timer,
              ),
              const SizedBox(width: 12),
              _buildSmallStat('Calorias', '$totalCal kcal', LucideIcons.flame),
              const SizedBox(width: 12),
              _buildSmallStat(
                'Peso Est.',
                '${weightLossKg.toStringAsFixed(3)} kg',
                LucideIcons.scale,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStat(String label, String value, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: cs.primary, size: 16),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.outfit(
                color: cs.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: cs.onSurfaceVariant,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    List<BarChartGroupData> barGroups = [];
    double maxDistance = 0;

    if (_selectedPeriodIndex == 0) {
      // Semana
      final startOfWeek = _referenceDate.subtract(
        Duration(days: _referenceDate.weekday % 7),
      );

      for (int i = 0; i < 7; i++) {
        final day = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        ).add(Duration(days: i));
        double dailyTotal = _allRuns
            .where(
              (r) =>
                  r.date.year == day.year &&
                  r.date.month == day.month &&
                  r.date.day == day.day,
            )
            .fold(0.0, (sum, r) => sum + r.distanceKm);

        if (dailyTotal > maxDistance) maxDistance = dailyTotal;
        barGroups.add(_makeGroupData(i, dailyTotal, maxDistance));
      }
    } else {
      // Mês
      final year = _referenceDate.year;
      final month = _referenceDate.month;
      final firstDayOfMonth = DateTime(year, month, 1);
      final lastDayOfMonth = DateTime(year, month + 1, 0);

      int weekIndex = 0;
      DateTime currentStart = firstDayOfMonth;

      while (currentStart.isBefore(
        lastDayOfMonth.add(const Duration(seconds: 1)),
      )) {
        final currentEnd = currentStart.add(const Duration(days: 7));
        final effectiveEnd = currentEnd.isAfter(lastDayOfMonth)
            ? lastDayOfMonth.add(const Duration(seconds: 1))
            : currentEnd;

        double weeklyTotal = _allRuns
            .where(
              (r) =>
                  r.date.isAfter(
                    currentStart.subtract(const Duration(seconds: 1)),
                  ) &&
                  r.date.isBefore(effectiveEnd),
            )
            .fold(0.0, (sum, r) => sum + r.distanceKm);

        if (weeklyTotal > maxDistance) maxDistance = weeklyTotal;
        barGroups.add(_makeGroupData(weekIndex, weeklyTotal, maxDistance));

        currentStart = currentEnd;
        weekIndex++;
      }
    }

    if (maxDistance == 0) maxDistance = 5.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxDistance * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Theme.of(context).colorScheme.surface,
            tooltipBorder: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.3),
            ),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toStringAsFixed(1)} km',
                GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                String text = '';
                if (_selectedPeriodIndex == 0) {
                  const days = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
                  text = days[value.toInt() % 7];
                } else {
                  text = 'S${value.toInt() + 1}';
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    text,
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y, double maxY) {
    Color barColor = AppColors.primaryNeon;
    if (maxY > 0) {
      double ratio = y / maxY;
      if (ratio > 0.7) {
        barColor = Colors.purpleAccent;
      } else if (ratio > 0.4) {
        barColor = Colors.orangeAccent;
      }
    }

    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: barColor,
          width: 8,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        ),
      ],
    );
  }

  Widget _buildActivitiesList() {
    return Column(
      children: [
        if (_recommendation != null && _selectedPeriodIndex == 0)
          _buildRecommendationCard(),
        _filteredRuns.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredRuns.length,
                itemBuilder: (context, index) {
                  final run = _filteredRuns[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 6,
                    ),
                    child: _buildRunCard(run),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildRecommendationCard() {
    final res = _recommendation!;
    final isAlert = res.emoji == '🔴' || res.emoji == '🟡';
    final isInfo = res.emoji == '📊' || res.emoji == '⏱️';
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        borderColor: res.isIncrease
            ? cs.primary.withValues(alpha: 0.3)
            : isAlert
            ? Colors.orangeAccent.withValues(alpha: 0.3)
            : cs.outline.withValues(alpha: 0.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(res.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  isInfo ? 'Status da Semana' : 'Dica de Evolução',
                  style: GoogleFonts.outfit(
                    color: cs.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              res.message,
              style: GoogleFonts.outfit(
                color: cs.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            if (!isInfo && !isAlert) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: res.isIncrease
                        ? cs.primary
                        : cs.outline.withValues(alpha: 0.15),
                    foregroundColor: res.isIncrease
                        ? cs.onPrimary
                        : cs.onSurface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    if (_userProfile != null) {
                      // Snapshot next week's goal
                      final now = DateTime.now();
                      final nextWeekDate = now.add(const Duration(days: 7));
                      final startOfNextWeek = nextWeekDate.subtract(
                        Duration(days: nextWeekDate.weekday - 1),
                      );
                      final day = startOfNextWeek
                          .difference(DateTime(startOfNextWeek.year, 1, 1))
                          .inDays;
                      final weekNum = (day / 7).floor() + 1;
                      final nextPeriodId =
                          '${startOfNextWeek.year}-W${weekNum.toString().padLeft(2, '0')}';
                      await _dbService.saveGoalHistory(
                        nextPeriodId,
                        'weekly',
                        res.recommendedGoal,
                      );

                      final newProfile = UserProfile(
                        name: _userProfile!.name,
                        age: _userProfile!.age,
                        weight: _userProfile!.weight,
                        height: _userProfile!.height,
                        profilePicturePath: _userProfile!.profilePicturePath,
                        weeklyGoal: res.recommendedGoal,
                        monthlyGoal: _userProfile!.monthlyGoal,
                        lastGoalUpdate: DateTime.now(),
                      );
                      await _dbService.saveUserProfile(newProfile);
                      setState(() {
                        _userProfile = newProfile;
                        _recommendation = null;
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Meta da próxima semana definida! 🚀',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    'DEFINIR META PRÓX. SEMANA: ${res.recommendedGoal.toStringAsFixed(1)} KM',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRunCard(RunModel run) {
    final cs = Theme.of(context).colorScheme;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RunDetailScreen(run: run)),
        ).then((_) => _loadData());
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: run.type == 'Caminhada'
                  ? Colors.blue.withValues(alpha: 0.1)
                  : cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              run.type == 'Caminhada'
                  ? LucideIcons.footprints
                  : LucideIcons.zap,
              color: run.type == 'Caminhada' ? Colors.blueAccent : cs.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${run.distanceKm.toStringAsFixed(2)} km',
                  style: GoogleFonts.outfit(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_formatDateShort(run.date)} • ${TimeUtils.formatDuration(run.durationSeconds)}',
                  style: GoogleFonts.outfit(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
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
                  color: cs.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'ritmo',
                style: GoogleFonts.outfit(
                  color: cs.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Icon(
            LucideIcons.chevronRight,
            color: cs.outline.withValues(alpha: 0.4),
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(
              LucideIcons.history,
              size: 48,
              color: cs.onSurfaceVariant.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma atividade neste período.',
              style: GoogleFonts.outfit(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Color _getGoalColor(double progress) {
    if (progress <= 0) return AppColors.primaryNeon.withValues(alpha: 0.3);

    // Dragon chasing tail: Chromatic progression
    if (progress < 0.5) {
      // 0 to 0.5: Cyan to Neon Green
      return Color.lerp(
        Colors.cyanAccent,
        AppColors.primaryNeon,
        progress * 2,
      )!;
    } else if (progress < 1.0) {
      // 0.5 to 1.0: Neon Green to Orange
      return Color.lerp(
        AppColors.primaryNeon,
        Colors.orangeAccent,
        (progress - 0.5) * 2,
      )!;
    } else if (progress < 1.5) {
      // 1.0 to 1.5: Orange to Pink/Purple
      return Color.lerp(
        Colors.orangeAccent,
        Colors.pinkAccent,
        (progress - 1.0) * 2,
      )!;
    } else {
      // Over 1.5: Deep Purple
      return Colors.deepPurpleAccent;
    }
  }
}
