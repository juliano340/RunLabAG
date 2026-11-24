/// Cache de read models compartilhado por todas as telas.
///
/// A chave inclui a revisão dos dados. Resultados de consultas iniciadas antes
/// de uma invalidação nunca são armazenados como atuais, e chamadas simultâneas
/// para a mesma chave compartilham um único Future (single-flight).
class ReadModelCache {
  int _revision = 0;
  final Map<String, Object?> _values = {};
  final Map<String, Future<Object?>> _inFlight = {};

  int get revision => _revision;

  void invalidate() {
    _revision++;
    _values.clear();
  }

  Future<T> getOrFetch<T>(String key, Future<T> Function() fetch) async {
    final version = _revision;
    final versionedKey = '$version:$key';
    final cached = _values[versionedKey];
    if (_values.containsKey(versionedKey) && cached is T) return cached;

    final pending = _inFlight[versionedKey];
    if (pending is Future<T>) return pending;

    late final Future<T> future;
    future = fetch()
        .then((value) {
          if (_revision == version) {
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
