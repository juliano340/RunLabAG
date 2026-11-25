import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/core/utils/clock.dart';
import 'package:runlabag/features/run/application/active_run_persistence.dart';
import 'package:runlabag/features/run/domain/repositories/active_run_store.dart';

class _FakeTimer implements Timer {
  final void Function(Timer timer) callback;
  bool _active = true;
  final int _ticks = 0;

  _FakeTimer(this.callback);

  @override
  bool get isActive => _active;

  @override
  int get tick => _ticks;

  @override
  void cancel() => _active = false;
}

class _FakeClock implements Clock {
  DateTime current;

  _FakeClock(this.current);

  @override
  DateTime now() => current;

  @override
  Timer periodic(Duration interval, void Function(Timer timer) callback) =>
      _FakeTimer(callback);
}

class _FakeStore implements ActiveRunStore {
  final List<Map<String, dynamic>> metaWrites = [];
  final List<String> routeWrites = [];
  Completer<void>? nextMetaGate;

  @override
  Future<void> saveMeta(Map<String, dynamic> data) async {
    final gate = nextMetaGate;
    if (gate != null) await gate.future;
    metaWrites.add(Map<String, dynamic>.from(data));
  }

  @override
  Future<void> saveRoute(String routeJson) async => routeWrites.add(routeJson);

  @override
  Future<void> clear() async {}
}

void main() {
  test('rota respeita intervalo, mas force sempre grava', () async {
    final clock = _FakeClock(DateTime(2026, 11, 24));
    final store = _FakeStore();
    final persistence = ActiveRunPersistence(store, clock);

    persistence.saveState(meta: {'n': 1}, routeJson: 'rota 1');
    await persistence.flush();
    clock.current = clock.current.add(const Duration(seconds: 29));
    persistence.saveState(meta: {'n': 2}, routeJson: 'rota 2');
    await persistence.flush();
    clock.current = clock.current.add(const Duration(seconds: 1));
    persistence.saveState(
      meta: {'n': 3},
      routeJson: 'rota 3',
      forceRoute: true,
    );
    await persistence.flush();

    expect(store.metaWrites, hasLength(3));
    expect(store.routeWrites, ['rota 1', 'rota 3']);
  });

  test(
    'finalização espera escrita antiga e publica finished por último',
    () async {
      final clock = _FakeClock(DateTime(2026, 11, 24));
      final store = _FakeStore();
      final persistence = ActiveRunPersistence(store, clock);
      final gate = Completer<void>();
      store.nextMetaGate = gate;

      persistence.saveState(meta: {'finished': 0}, routeJson: 'antiga');
      final finishing = persistence.finish(
        meta: {'finished': 1},
        routeJson: 'final',
      );
      await Future<void>.delayed(Duration.zero);
      expect(store.metaWrites, isEmpty);

      gate.complete();
      await finishing;

      expect(store.metaWrites.map((row) => row['finished']), [0, 1]);
      expect(store.routeWrites, ['antiga', 'final']);
    },
  );
}
