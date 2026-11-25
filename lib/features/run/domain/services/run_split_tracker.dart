import '../../../../core/domain/models/run_split.dart';
import 'run_finalization_service.dart';

/// Acumula splits e controla o último quilômetro já anunciado.
class RunSplitTracker {
  List<RunSplit> _splits = [];
  int _lastKmNotified = 0;
  int _lastSplitTimeSeconds = 0;
  int _lastSplitCalories = 0;

  List<RunSplit> get splits => _splits;
  int get lastKmNotified => _lastKmNotified;

  void restore({required List<RunSplit> splits, required int lastKmNotified}) {
    _splits = splits;
    _lastKmNotified = lastKmNotified;
    _lastSplitTimeSeconds = _splits.fold(
      0,
      (sum, split) => sum + split.timeSeconds,
    );
    _lastSplitCalories = _splits.fold(0, (sum, split) => sum + split.calories);
  }

  void reset() {
    _splits = [];
    _lastKmNotified = 0;
    _lastSplitTimeSeconds = 0;
    _lastSplitCalories = 0;
  }

  /// Retorna o split criado quando um novo quilômetro é completado.
  RunSplit? recordDistance({
    required double distanceKm,
    required int elapsedSeconds,
    required int totalCalories,
  }) {
    final currentKm = distanceKm.floor();
    if (currentKm <= _lastKmNotified) return null;

    final split = RunSplit(
      timeSeconds: elapsedSeconds - _lastSplitTimeSeconds,
      calories: totalCalories - _lastSplitCalories,
    );
    _splits.add(split);
    _lastSplitTimeSeconds = elapsedSeconds;
    _lastSplitCalories = totalCalories;
    _lastKmNotified = currentKm;
    return split;
  }

  /// Fecha o treino com um split parcial quando a regra existente exigir.
  RunSplit? finalize({
    required double distanceKm,
    required int elapsedSeconds,
    required int totalCalories,
  }) {
    if (!RunFinalizationService.shouldAddFinalSplit(
      distanceKm: distanceKm,
      lastKmNotified: _lastKmNotified,
    )) {
      return null;
    }

    final split = RunSplit(
      timeSeconds: RunFinalizationService.calculateFinalSplitTime(
        elapsedSeconds: elapsedSeconds,
        lastSplitTimeSeconds: _lastSplitTimeSeconds,
      ),
      calories: RunFinalizationService.calculateFinalSplitCalories(
        totalCalories: totalCalories,
        lastSplitCalories: _lastSplitCalories,
      ),
    );
    _splits.add(split);
    _lastKmNotified = RunFinalizationService.calculateFinalNotifiedKm(
      distanceKm,
    );
    return split;
  }
}
