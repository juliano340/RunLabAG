import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/domain/models/run_model.dart';
import '../../../core/domain/models/user_profile.dart';
import '../../../core/domain/models/user_stats.dart';
import '../../../core/domain/repositories/active_run_repository.dart';
import '../../../core/domain/repositories/run_repository.dart';
import '../../../core/domain/repositories/stats_repository.dart';
import '../../../core/domain/repositories/user_repository.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/latest_request.dart';
import 'home_stats_window_store.dart';

/// Estado e consultas da Home, sem dependências de BuildContext ou navegação.
class HomeDashboardViewModel extends ChangeNotifier {
  static const List<String> statsPeriodLabels = [
    'Tudo',
    '7d',
    '15d',
    '30d',
    '60d',
    '90d',
  ];

  final StatsRepository _statsRepository;
  final UserRepository _userRepository;
  final RunRepository _runRepository;
  final ActiveRunRepository _activeRunRepository;
  final HomeStatsWindowStore _statsWindowStore;
  final Clock _clock;
  final bool _embedded;
  final LatestRequest _latestLoad = LatestRequest();

  Listenable? _dataChanges;
  Future<void> _windowWrites = Future<void>.value();
  UserStats _stats = UserStats.empty;
  List<double> _weeklyProgress = List<double>.unmodifiable(
    List<double>.filled(7, 0),
  );
  UserProfile? _profile;
  RunModel? _lastRun;
  Map<String, dynamic>? _pendingRecovery;
  Object? _error;
  int _statsPeriod = 0;
  bool _isLoading = true;
  bool _hasLoaded = false;
  bool _initialized = false;
  bool _disposed = false;

  HomeDashboardViewModel({
    required StatsRepository statsRepository,
    required UserRepository userRepository,
    required RunRepository runRepository,
    required ActiveRunRepository activeRunRepository,
    required HomeStatsWindowStore statsWindowStore,
    required Clock clock,
    bool embedded = false,
    Listenable? dataChanges,
  }) : _statsRepository = statsRepository,
       _userRepository = userRepository,
       _runRepository = runRepository,
       _activeRunRepository = activeRunRepository,
       _statsWindowStore = statsWindowStore,
       _clock = clock,
       _embedded = embedded,
       _dataChanges = dataChanges {
    _dataChanges?.addListener(_onDataChanged);
  }

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get hasError => _error != null;
  Object? get error => _error;
  UserStats get stats => _stats;
  List<double> get weeklyProgress => _weeklyProgress;
  UserProfile? get profile => _profile;
  RunModel? get lastRun => _lastRun;
  int get selectedStatsPeriod => _statsPeriod;
  bool get hasPendingRecovery => _pendingRecovery != null;

  double get weeklyTotal =>
      _weeklyProgress.fold<double>(0, (sum, item) => sum + item);

  double get weeklyGoal => _profile?.weeklyGoal ?? 20.0;

  double get rawGoalProgress => weeklyGoal > 0 ? weeklyTotal / weeklyGoal : 0.0;

  double get goalProgress => rawGoalProgress.clamp(0.0, 1.0);

  int get todayIndex => _clock.now().weekday % 7;

  double get chartMaxY {
    var maxDistance = 0.0;
    for (final distance in _weeklyProgress) {
      if (distance > maxDistance) maxDistance = distance;
    }
    // Piso de 2 km para semanas leves + headroom para a barra não encostar
    // no teto. Sem o piso antigo de 10 km: treinos curtos usam a tela toda.
    return maxDistance < 2 ? 2 : (maxDistance * 1.2).ceilToDouble();
  }

  String get greeting {
    final hour = _clock.now().hour;
    if (hour >= 5 && hour < 12) return 'Bom dia,';
    if (hour >= 12 && hour < 18) return 'Boa tarde,';
    return 'Boa noite,';
  }

  String get lastRunDurationLabel =>
      _formatRunDuration(_lastRun?.durationSeconds ?? 0);

  /// Restaura a janela antes da primeira carga.
  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;

    try {
      final storedPeriod = await _statsWindowStore.readStatsPeriod();
      if (_disposed) return;
      _statsPeriod = _validStatsPeriod(storedPeriod);
      _notify();
    } catch (error) {
      _publishError(error);
    }

    await load();
  }

  /// Atualiza todos os dados usados pela Home em paralelo.
  Future<void> load() async {
    if (_disposed) return;
    final requestId = _latestLoad.begin();
    _isLoading = !_hasLoaded;
    _error = null;
    _notify();

    try {
      final futures = <Future<Object?>>[
        _statsRepository.getUserStats(since: _statsSince),
        _statsRepository.getWeeklyProgress(),
        _userRepository.getUserProfile(),
        _runRepository.getLastRunSummary(),
        if (!_embedded)
          _activeRunRepository.getActiveRunMeta().catchError((
            Object error,
            StackTrace stack,
          ) {
            debugPrint('Home: não foi possível verificar treino ativo: $error');
            return null;
          }),
      ];
      final results = await Future.wait<Object?>(futures);
      if (_disposed || !_latestLoad.isCurrent(requestId)) return;

      _stats = results[0] as UserStats;
      _weeklyProgress = List<double>.unmodifiable(results[1] as List<double>);
      _profile = results[2] as UserProfile?;
      _lastRun = results[3] as RunModel?;
      final activeRunMeta = _embedded
          ? null
          : results[4] as Map<String, dynamic>?;
      _pendingRecovery = activeRunMeta == null
          ? null
          : Map<String, dynamic>.unmodifiable(activeRunMeta);
      _hasLoaded = true;
      _isLoading = false;
      _error = null;
      _notify();
    } catch (error) {
      _publishError(error, requestId: requestId);
    }
  }

  Future<void> changeStatsPeriod(int statsPeriod) async {
    if (_disposed ||
        !_isValidStatsPeriod(statsPeriod) ||
        statsPeriod == _statsPeriod) {
      return;
    }

    final requestId = _latestLoad.begin();
    final since = _statsSinceFor(statsPeriod);
    _statsPeriod = statsPeriod;
    _error = null;
    _notify();

    await Future.wait<void>([
      _persistStatsPeriod(requestId, statsPeriod),
      _loadStatsForPeriod(requestId, since),
    ]);
  }

  /// Consome o evento de recuperação para que a UI o exiba uma única vez.
  Map<String, dynamic>? takePendingRecovery() {
    final recovery = _pendingRecovery;
    _pendingRecovery = null;
    return recovery;
  }

  Future<void> discardActiveRun() async {
    if (_disposed) return;
    try {
      await _activeRunRepository.clearActiveRun();
      if (_disposed) return;
      _pendingRecovery = null;
      _error = null;
      _notify();
    } catch (error) {
      _publishError(error);
      rethrow;
    }
  }

  /// A rota completa só é lida quando o usuário escolhe retomar/salvar.
  Future<Map<String, dynamic>?> loadActiveRunForResume() async {
    if (_disposed) return null;
    try {
      return await _activeRunRepository.getActiveRun();
    } catch (error) {
      _publishError(error);
      rethrow;
    }
  }

  /// Permite trocar a fonte de mudanças sem recriar a ViewModel.
  void updateDataChanges(Listenable? dataChanges) {
    if (_disposed || identical(_dataChanges, dataChanges)) return;
    _dataChanges?.removeListener(_onDataChanged);
    _dataChanges = dataChanges;
    _dataChanges?.addListener(_onDataChanged);
  }

  void _onDataChanged() {
    unawaited(load());
  }

  DateTime? get _statsSince => _statsSinceFor(_statsPeriod);

  DateTime? _statsSinceFor(int statsPeriod) {
    final days = switch (statsPeriod) {
      1 => 7,
      2 => 15,
      3 => 30,
      4 => 60,
      5 => 90,
      _ => 0,
    };
    return days == 0 ? null : _clock.now().subtract(Duration(days: days));
  }

  Future<void> _loadStatsForPeriod(int requestId, DateTime? since) async {
    try {
      final stats = await _statsRepository.getUserStats(since: since);
      if (_disposed || !_latestLoad.isCurrent(requestId)) return;
      _stats = stats;
      _isLoading = false;
      _error = null;
      _notify();
    } catch (error) {
      _publishError(error, requestId: requestId);
    }
  }

  Future<void> _persistStatsPeriod(int requestId, int statsPeriod) async {
    try {
      await _queueWindowWrite(statsPeriod);
    } catch (error) {
      _publishError(error, requestId: requestId);
    }
  }

  // Escritas rápidas são serializadas para uma janela antiga nunca sobrescrever
  // a mais recente no SharedPreferences.
  Future<void> _queueWindowWrite(int statsPeriod) {
    final write = _windowWrites.then(
      (_) => _statsWindowStore.writeStatsPeriod(statsPeriod),
    );
    _windowWrites = write.then<void>((_) {}, onError: (Object _) {});
    return write;
  }

  void _publishError(Object error, {int? requestId}) {
    if (_disposed || (requestId != null && !_latestLoad.isCurrent(requestId))) {
      return;
    }
    _isLoading = false;
    _error = error;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _isValidStatsPeriod(int statsPeriod) =>
      statsPeriod >= 0 && statsPeriod < statsPeriodLabels.length;

  int _validStatsPeriod(int? statsPeriod) =>
      statsPeriod != null && _isValidStatsPeriod(statsPeriod) ? statsPeriod : 0;

  String _formatRunDuration(int seconds) {
    if (seconds >= 3600) {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '${hours}h ${minutes}m';
    }
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds.toString().padLeft(2, '0')}s';
  }

  @override
  void dispose() {
    _disposed = true;
    _latestLoad.begin();
    _dataChanges?.removeListener(_onDataChanged);
    _dataChanges = null;
    super.dispose();
  }
}
