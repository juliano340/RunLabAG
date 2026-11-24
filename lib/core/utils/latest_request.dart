/// Garante que apenas a requisição mais recente possa publicar resultado.
class LatestRequest {
  int _current = 0;

  int begin() => ++_current;

  bool isCurrent(int requestId) => requestId == _current;
}
