import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/core/domain/repositories/run_repository.dart';
import 'package:runlabag/core/services/pace_zone_backfill_service.dart';

class _FakeRunRepository implements RunRepository {
  int reads = 0;
  String? savedRunId;
  Map<String, double>? savedZones;

  @override
  Future<List<Map<String, dynamic>>> getRunsMissingPaceZones({
    int limit = 40,
  }) async {
    reads++;
    if (reads > 1) return [];
    return [
      {
        'id': 'run_antigo',
        'distanceKm': 0.1,
        'durationSeconds': 60,
        'route':
            '[[{"lat":-23.55,"lng":-46.63},{"lat":-23.5501,"lng":-46.6301}]]',
        'splits': '[]',
      },
    ];
  }

  @override
  Future<void> savePaceZones(
    String runId,
    Map<String, double> distanceByZone,
  ) async {
    savedRunId = runId;
    savedZones = Map<String, double>.from(distanceByZone);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('backfill processa um lote e persiste as faixas calculadas', () async {
    final repository = _FakeRunRepository();

    final processed = await PaceZoneBackfillService(repository).runBatch();

    expect(processed, 1);
    expect(repository.savedRunId, 'run_antigo');
    expect(repository.savedZones, isNotEmpty);
  });
}
