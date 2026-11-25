import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/utils/clock.dart';
import '../domain/repositories/active_run_store.dart';

/// Serializa as escritas do rascunho sem deixar o controller conhecer SQLite.
///
/// Metadados e rota têm filas independentes. A finalização espera ambas antes
/// de publicar `finished = 1`, impedindo que uma escrita antiga regrida o
/// rascunho depois do snapshot final.
class ActiveRunPersistence {
  static const routePersistInterval = Duration(seconds: 30);

  final ActiveRunStore _store;
  final Clock _clock;

  Future<void> _metaWrites = Future<void>.value();
  Future<void> _routeWrites = Future<void>.value();
  DateTime? _lastRoutePersistAt;

  ActiveRunPersistence(this._store, this._clock);

  Future<void> flush() => Future.wait([_metaWrites, _routeWrites]);

  void saveState({
    required Map<String, dynamic> meta,
    required String routeJson,
    bool forceRoute = false,
  }) {
    _queueMeta(meta);
    _queueRoute(routeJson, force: forceRoute);
  }

  Future<void> finish({
    required Map<String, dynamic> meta,
    required String routeJson,
  }) async {
    await flush();
    try {
      await _store.saveMeta(meta);
      await _store.saveRoute(routeJson);
    } catch (e) {
      debugPrint('RunSession: falha ao persistir treino finalizado: $e');
    }
  }

  Future<void> clear() => _store.clear();

  void _queueMeta(Map<String, dynamic> payload) {
    _metaWrites = _metaWrites.then((_) async {
      try {
        await _store.saveMeta(payload);
      } catch (e) {
        debugPrint('RunSession: falha ao persistir metadados: $e');
      }
    });
  }

  void _queueRoute(String payload, {required bool force}) {
    final now = _clock.now();
    final last = _lastRoutePersistAt;
    if (!force && last != null && now.difference(last) < routePersistInterval) {
      return;
    }
    _lastRoutePersistAt = now;
    _routeWrites = _routeWrites.then((_) async {
      try {
        await _store.saveRoute(payload);
      } catch (e) {
        debugPrint('RunSession: falha ao persistir rota: $e');
        _lastRoutePersistAt = null;
      }
    });
  }
}
