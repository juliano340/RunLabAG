import 'dart:async';

import 'package:flutter/foundation.dart';

/// Domínios de dados que podem mudar de forma independente.
enum DataScope {
  runs,
  profile,
  goals,
  monitoredDistances,
  achievements,
  paceZones,
  strength,
  all,
}

/// Fonte única de revisão e notificação das mudanças persistidas.
///
/// Telas e cache consomem o mesmo sinal, evitando invalidação global e
/// recarregamentos desnecessários.
class DataChangeHub {
  final StreamController<Set<DataScope>> _changes =
      StreamController<Set<DataScope>>.broadcast();
  final Map<DataScope, int> _revisions = {
    for (final scope in DataScope.values) scope: 0,
  };
  final Map<DataScope, ValueNotifier<int>> _signals = {
    for (final scope in DataScope.values) scope: ValueNotifier<int>(0),
  };
  final Map<String, Listenable> _listenables = {};

  Stream<Set<DataScope>> get changes => _changes.stream;

  int revision(DataScope scope) => _revisions[scope] ?? 0;

  /// Assinatura estável para um conjunto de dependências.
  String signature(Set<DataScope> scopes) {
    final effective = scopes.contains(DataScope.all)
        ? const {DataScope.all}
        : {DataScope.all, ...scopes};
    final ordered = effective.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return ordered.map((scope) => '${scope.name}:${revision(scope)}').join('|');
  }

  /// Listener combinado. `all` participa de todo listener para que reset e
  /// restauração continuem alcançando todas as abas.
  Listenable listenableFor(Set<DataScope> scopes) {
    final ordered = ({...scopes, DataScope.all}.toList())
      ..sort((a, b) => a.index.compareTo(b.index));
    final key = ordered.map((scope) => scope.name).join('|');
    return _listenables.putIfAbsent(key, () {
      final signals = <Listenable>[
        for (final scope in ordered) _signals[scope]!,
      ];
      return Listenable.merge(signals);
    });
  }

  void emit(Set<DataScope> scopes) {
    if (scopes.isEmpty) return;
    final normalized = scopes.contains(DataScope.all)
        ? const {DataScope.all}
        : Set<DataScope>.unmodifiable(scopes);
    for (final scope in normalized) {
      _revisions[scope] = revision(scope) + 1;
      _signals[scope]!.value++;
    }
    _changes.add(normalized);
  }

  void dispose() {
    for (final signal in _signals.values) {
      signal.dispose();
    }
    _changes.close();
  }
}
