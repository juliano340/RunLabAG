import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/core/utils/latest_request.dart';

void main() {
  test('apenas a última requisição é considerada atual', () {
    final requests = LatestRequest();
    final first = requests.begin();
    final second = requests.begin();

    expect(requests.isCurrent(first), isFalse);
    expect(requests.isCurrent(second), isTrue);
  });
}
