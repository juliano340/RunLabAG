import 'data_change_hub.dart';

/// Cache de read models compartilhado por todas as telas.
///
/// A versão de cada entrada considera apenas os escopos dos quais ela depende.
/// Consultas iniciadas antes de uma mudança não são armazenadas como atuais e
/// chamadas simultâneas para a mesma chave compartilham um Future.
class ReadModelCache {
  final DataChangeHub _hub;
  final Map<String, Object?> _values = {};
  final Map<String, Future<Object?>> _inFlight = {};

  ReadModelCache({DataChangeHub? hub}) : _hub = hub ?? DataChangeHub();

  DataChangeHub get changes => _hub;
  int get revision => _hub.revision(DataScope.all);

  void invalidate([Set<DataScope> scopes = const {DataScope.all}]) {
    _hub.emit(scopes);
  }

  Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetch, {
    Set<DataScope> scopes = const {DataScope.all},
  }) async {
    final signature = _hub.signature(scopes);
    final versionedKey = '$signature:$key';
    final cached = _values[versionedKey];
    if (_values.containsKey(versionedKey) && cached is T) return cached;

    final pending = _inFlight[versionedKey];
    if (pending is Future<T>) return pending;

    late final Future<T> future;
    future = fetch()
        .then((value) {
          if (_hub.signature(scopes) == signature) {
            _values[versionedKey] = value;
            if (_values.length > 200) {
              _values.remove(_values.keys.first);
            }
          }
          return value;
        })
        .whenComplete(() {
          if (identical(_inFlight[versionedKey], future)) {
            _inFlight.remove(versionedKey);
          }
        });
    _inFlight[versionedKey] = future;
    return future;
  }
}
