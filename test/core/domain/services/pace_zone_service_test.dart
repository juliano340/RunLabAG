import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:runlabag/core/domain/models/run_split.dart';
import 'package:runlabag/core/domain/services/pace_zone_service.dart';

void main() {
  // 1 grau de latitude ≈ 111.19 km; 0.001° ≈ 111 m.
  LatLng point(double lat) => LatLng(lat, -46.6333);

  group('PaceZoneService.limites (mix universal + média pessoal)', () {
    test('caminhada é absoluta: >= 12:00/km para qualquer centro', () {
      final zone = PaceZoneService.zoneFor(
        paceSecPerKm: 720,
        centerSecPerKm: 300,
      );
      expect(zone, PaceZone.walking);
    });

    test('muito lento: >= centro * 1.15', () {
      final zone = PaceZoneService.zoneFor(
        paceSecPerKm: 460,
        centerSecPerKm: 400,
      );
      expect(zone, PaceZone.slow);
    });

    test('acelerando: <= centro * 0.85', () {
      final zone = PaceZoneService.zoneFor(
        paceSecPerKm: 335,
        centerSecPerKm: 400,
      );
      expect(zone, PaceZone.fast);
    });

    test('corrida: dentro da banda central', () {
      final zone = PaceZoneService.zoneFor(
        paceSecPerKm: 390,
        centerSecPerKm: 400,
      );
      expect(zone, PaceZone.running);
    });

    test('centro é a média entre referência universal e média do treino', () {
      // (420 + 600) / 2 = 510
      expect(
        PaceZoneService.centerSecPerKm(runAvgSecPerKm: 600),
        510,
      );
    });

    test('sem média do treino, centro usa só a referência universal', () {
      expect(
        PaceZoneService.centerSecPerKm(runAvgSecPerKm: null),
        PaceZoneService.universalRunPaceSecPerKm.toDouble(),
      );
    });
  });

  group('PaceZoneService.analyze com tempos por ponto', () {
    test('rota inteira caminhando → tudo azul e 100% caminhada', () {
      final result = PaceZoneService.analyze(
        route: [
          [point(0), point(0.001), point(0.002), point(0.003)],
        ],
        routeTimes: [
          [0, 134, 268, 402],
        ],
        distanceKm: 0.333,
        durationSeconds: 402,
        splits: const [],
      );

      expect(result.segments, isNotEmpty);
      expect(result.segments.every((s) => s.zone == PaceZone.walking), isTrue);
      final walkKm = result.distanceByZoneKm[PaceZone.walking] ?? 0;
      final total = result.distanceByZoneKm.values.fold(0.0, (a, b) => a + b);
      expect(walkKm / total, closeTo(1.0, 0.01));
    });

    test('rota rápida → faixa acelerando', () {
      final result = PaceZoneService.analyze(
        route: [
          [point(0), point(0.001), point(0.002), point(0.003)],
        ],
        routeTimes: [
          [0, 33, 66, 99],
        ],
        distanceKm: 0.333,
        durationSeconds: 99,
        splits: const [],
      );

      expect(result.segments.every((s) => s.zone == PaceZone.fast), isTrue);
    });

    test('trechos vizinhos da mesma faixa são fundidos e contínuos', () {
      final result = PaceZoneService.analyze(
        route: [
          [
            point(0),
            point(0.0005),
            point(0.0010),
            point(0.0015),
            point(0.0020),
          ],
        ],
        routeTimes: [
          [0, 40, 80, 120, 160],
        ],
        distanceKm: 0.222,
        durationSeconds: 160,
        splits: const [],
      );

      // Pace ~720 s/km em todos os trechos → mesma faixa (caminhada), então
      // o merge deve produzir UM único segmento contínuo dentro do segmento.
      expect(result.segments.length, 1);
      expect(result.segments.first.points.length, 5);
      // Primeiro ponto fica cru (o início da linha não "pula")…
      expect(result.segments.first.points.first, point(0));
      // …e o último converge para o cru, mas a suavização de desenho deixa
      // o ponto um passo atrás (EMA), não igual ao ponto bruto.
      expect(
        (result.segments.first.points.last.latitude - 0.0020).abs(),
        lessThan(0.001),
      );
    });

    test('segmentos separados (pausa) nunca são fundidos entre si', () {
      final result = PaceZoneService.analyze(
        route: [
          [point(0), point(0.001), point(0.002)],
          [point(0.002), point(0.003), point(0.004)],
        ],
        routeTimes: [
          [0, 40, 80],
          [100, 140, 180],
        ],
        distanceKm: 0.444,
        durationSeconds: 180,
        splits: const [],
      );

      // Pode fundir dentro de cada segmento, mas os pontos resultantes
      // não podem pular da pausa: nenhum segmento atravessa a fronteira.
      for (final seg in result.segments) {
        for (var i = 1; i < seg.points.length; i++) {
          final jump = (seg.points[i].latitude - seg.points[i - 1].latitude)
              .abs();
          expect(jump < 0.0015, isTrue,
              reason: 'segmento atravessou uma pausa');
        }
      }
      expect(result.segments, isNotEmpty);
    });

    test('tempos com shape inválido caem para o fallback', () {
      final result = PaceZoneService.analyze(
        route: [
          [point(0), point(0.001), point(0.002)],
        ],
        routeTimes: [
          [0, 40], // tamanho diferente do segmento
        ],
        distanceKm: 0.222,
        durationSeconds: 80,
        splits: const [],
      );

      // Sem times e sem splits → cor única pela média.
      expect(result.segments.length, 1);
      expect(result.distanceByZoneKm.length, 1);
    });
  });

  group('PaceZoneService.analyze fallback por voltas (treinos antigos)', () {
    test('trechos recebem o pace da volta correspondente', () {
      // Rota de ~1.33 km: 12 pares de ~111 m.
      final lats = List.generate(13, (i) => 0.0005 * i * 2);
      final route = [lats.map(point).toList()];
      final splits = <RunSplit>[
        RunSplit(timeSeconds: 650, calories: 100),
        RunSplit(timeSeconds: 400, calories: 50),
      ];

      final result = PaceZoneService.analyze(
        route: route,
        routeTimes: const [],
        distanceKm: 2.0,
        durationSeconds: 1200,
        splits: splits,
      );

      expect(result.segments, isNotEmpty);
      final zones = result.segments.map((s) => s.zone).toSet();
      // km 0 a 10:50/km (650 s/km vs centro 510) → muito lento;
      // km 1 a 6:40/km (400 s/km) → acelerando.
      expect(zones, contains(PaceZone.slow));
      expect(zones, contains(PaceZone.fast));
    });
  });

  group('PaceZoneService.analyze sem nenhum dado de ritmo', () {
    test('rota sem tempos e sem voltas → faixa única pela média', () {
      final result = PaceZoneService.analyze(
        route: [
          [point(0), point(0.001), point(0.002)],
        ],
        routeTimes: const [],
        distanceKm: 0.222,
        durationSeconds: 67, // média ~302 s/km → fast com centro ~360
        splits: const [],
      );

      expect(result.segments.length, 1);
      expect(result.segments.first.zone, PaceZone.fast);
      final total = result.distanceByZoneKm.values.fold(0.0, (a, b) => a + b);
      expect(total, closeTo(0.222, 0.005));
    });

    test('rota vazia → resultado vazio', () {
      final result = PaceZoneService.analyze(
        route: const [],
        routeTimes: const [],
        distanceKm: 5,
        durationSeconds: 1800,
        splits: const [],
      );

      expect(result.segments, isEmpty);
      expect(result.distanceByZoneKm, isEmpty);
    });

    test('sem duração → zona padrão de corrida', () {
      final result = PaceZoneService.analyze(
        route: [
          [point(0), point(0.001)],
        ],
        routeTimes: const [],
        distanceKm: 0.111,
        durationSeconds: 0,
        splits: const [],
      );

      expect(result.segments.first.zone, PaceZone.running);
    });
  });

  group('PaceZoneService.gradientColorFor (degradê de ritmo)', () {
    test('extremos batem nas cores das faixas', () {
      final slow = PaceZoneService.gradientColorFor(
        paceSecPerKm: 900,
        centerSecPerKm: 420,
      );
      final fast = PaceZoneService.gradientColorFor(
        paceSecPerKm: 300,
        centerSecPerKm: 420,
      );
      expect(slow, PaceZone.walking.color);
      expect(fast, PaceZone.fast.color);
    });

    test('pace exatamente no centro → cor pura de corrida', () {
      final c = PaceZoneService.gradientColorFor(
        paceSecPerKm: 420,
        centerSecPerKm: 420,
      );
      expect(c, PaceZone.running.color);
    });

    test('quantização: paces próximos geram o mesmo tom (fundem trechos)', () {
      // Centro 420 → muito lento em 483: 481 e 477 caem no mesmo balde
      // quantizado (a fronteira com o tom seguinte está em ~475,1).
      final a = PaceZoneService.gradientColorFor(
        paceSecPerKm: 481,
        centerSecPerKm: 420,
      );
      final b = PaceZoneService.gradientColorFor(
        paceSecPerKm: 477,
        centerSecPerKm: 420,
      );
      expect(a, b);
    });

    test('centro degenerado (pior que caminhada) não quebra a rampa', () {
      final c = PaceZoneService.gradientColorFor(
        paceSecPerKm: 900,
        centerSecPerKm: 800,
      );
      expect(c, PaceZone.walking.color);
    });
  });

  group('PaceZoneService.smoothedForDrawing (linha mais amigável)', () {
    test('mantém o número de pontos e o primeiro cru', () {
      final pts = [point(0), point(0.001), point(0.002), point(0.003)];
      final out = PaceZoneService.smoothedForDrawing(pts);
      expect(out.length, pts.length);
      expect(out.first, pts.first);
    });

    test('abafa a tremida: variação total desenhada é menor que a bruta', () {
      // Zigue-zague de GPS: avança 111 m e "volta" 55 m, repetido.
      final pts = [
        point(0), point(0.001), point(0.0005), point(0.0015),
        point(0.001), point(0.002),
      ];
      double variation(List<LatLng> l) {
        var v = 0.0;
        for (var i = 1; i < l.length; i++) {
          v += (l[i].latitude - l[i - 1].latitude).abs();
        }
        return v;
      }

      final out = PaceZoneService.smoothedForDrawing(pts);
      expect(variation(out), lessThan(variation(pts)));
    });

    test('rota curta (menos de 3 pontos) volta intacta', () {
      final pts = [point(0), point(0.001)];
      expect(PaceZoneService.smoothedForDrawing(pts), pts);
    });
  });
}
