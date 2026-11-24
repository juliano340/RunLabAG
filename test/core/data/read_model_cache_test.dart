import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/core/data/data_change_hub.dart';
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

  test('invalidação por escopo preserva cache independente', () async {
    final cache = ReadModelCache();
    var profileCalls = 0;
    var runCalls = 0;

    Future<String> profile() async {
      profileCalls++;
      return 'profile';
    }

    Future<String> runs() async {
      runCalls++;
      return 'runs';
    }

    expect(
      await cache.getOrFetch('profile', profile, scopes: {DataScope.profile}),
      'profile',
    );
    expect(
      await cache.getOrFetch('runs', runs, scopes: {DataScope.runs}),
      'runs',
    );

    cache.invalidate({DataScope.profile});

    expect(
      await cache.getOrFetch('profile', profile, scopes: {DataScope.profile}),
      'profile',
    );
    expect(
      await cache.getOrFetch('runs', runs, scopes: {DataScope.runs}),
      'runs',
    );
    expect(profileCalls, 2);
    expect(runCalls, 1);
  });

  test(
    'mudança de qualquer dependência invalida a entrada combinada',
    () async {
      final cache = ReadModelCache();
      var calls = 0;

      Future<int> fetch() async {
        calls++;
        return calls;
      }

      const scopes = {DataScope.runs, DataScope.profile};
      expect(await cache.getOrFetch('mixed', fetch, scopes: scopes), 1);
      cache.invalidate({DataScope.goals});
      expect(await cache.getOrFetch('mixed', fetch, scopes: scopes), 1);
      cache.invalidate({DataScope.profile});
      expect(await cache.getOrFetch('mixed', fetch, scopes: scopes), 2);
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
