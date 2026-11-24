import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/core/data/read_model_cache.dart';

void main() {
  test('armazena resultado e evita nova consulta', () async {
    final cache = ReadModelCache();
    var calls = 0;

    Future<int> fetch() async {
      calls++;
      return 42;
    }

    expect(await cache.getOrFetch('value', fetch), 42);
    expect(await cache.getOrFetch('value', fetch), 42);
    expect(calls, 1);
  });

  test('consultas simultâneas compartilham um único Future', () async {
    final cache = ReadModelCache();
    final gate = Completer<int>();
    var calls = 0;

    Future<int> fetch() {
      calls++;
      return gate.future;
    }

    final first = cache.getOrFetch('value', fetch);
    final second = cache.getOrFetch('value', fetch);
    expect(calls, 1);

    gate.complete(7);
    expect(await Future.wait([first, second]), [7, 7]);
  });

  test('invalidação força nova leitura', () async {
    final cache = ReadModelCache();
    var value = 1;

    expect(await cache.getOrFetch('value', () async => value), 1);
    cache.invalidate();
    value = 2;
    expect(await cache.getOrFetch('value', () async => value), 2);
  });

  test(
    'resultado iniciado antes da invalidação não vira cache atual',
    () async {
      final cache = ReadModelCache();
      final oldGate = Completer<int>();
      final oldRead = cache.getOrFetch('value', () => oldGate.future);

      cache.invalidate();
      expect(await cache.getOrFetch('value', () async => 2), 2);

      oldGate.complete(1);
      expect(await oldRead, 1);
      expect(await cache.getOrFetch('value', () async => 3), 2);
    },
  );

  test('cache aceita resultado nulo', () async {
    final cache = ReadModelCache();
    var calls = 0;

    Future<String?> fetch() async {
      calls++;
      return null;
    }

    expect(await cache.getOrFetch<String?>('nullable', fetch), isNull);
    expect(await cache.getOrFetch<String?>('nullable', fetch), isNull);
    expect(calls, 1);
  });
}
