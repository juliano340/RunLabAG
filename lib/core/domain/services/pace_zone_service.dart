import 'dart:ui';
import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../theme/app_colors.dart';
import 'package:runlabag/core/domain/models/run_split.dart';

/// Faixas de ritmo exibidas no mapa colorido do treino.
enum PaceZone {
  /// Caminhada — limiar absoluto (fisiológico, igual para todos).
  walking(Color(0xFF29B6F6), 'Caminhada'),

  /// Muito mais lento que o ritmo esperado.
  slow(Color(0xFFFF9800), 'Muito lento'),

  /// Ritmo confortável (banda central).
  running(AppColors.primaryNeon, 'Corrida'),

  /// Acelerando — bem mais rápido que o ritmo esperado.
  fast(Color(0xFFAB47BC), 'Acelerando');

  const PaceZone(this.color, this.label);
  final Color color;
  final String label;
}

/// Um trecho contínuo da rota pintado com uma única cor do degradê.
///
/// [zone] alimenta as estatísticas por faixa; [color] é o tom efetivo do
/// degradê usado para desenhar — pode ser um intermediário entre duas
/// faixas. Os [points] vêm suavizados para exibição; distância e faixas
/// são calculadas sobre os pontos crus do GPS.
class PaceZoneSegment {
  final PaceZone zone;
  final List<LatLng> points;
  final Color color;

  const PaceZoneSegment(this.zone, this.points, this.color);
}

/// Resultado da análise de ritmo de um treino.
class PaceZoneResult {
  /// Trechos para desenhar as polylines coloridas (pontos consecutivos
  /// compartilham o ponto de fronteira para a linha ficar contínua).
  final List<PaceZoneSegment> segments;

  /// Distância total (km) percorrida em cada faixa.
  final Map<PaceZone, double> distanceByZoneKm;

  const PaceZoneResult(this.segments, this.distanceByZoneKm);
}

/// Analisa a rota de um treino e classifica cada trecho em faixas de ritmo.
///
/// Estratégia em cascata:
/// 1. Tempos por ponto (novos treinos) → ritmo real por trecho de ~50m;
/// 2. Voltas/kms (treinos antigos) → ritmo por km aplicado ao trecho;
/// 3. Nada disponível → ritmo médio uniforme do treino inteiro.
///
/// Os limites entre faixas são um MIX do que o usuário escolheu:
/// - Caminhada é absoluta (>= 12:00/km) — realidade fisiológica para todos;
/// - As demais faixas orbitam um "centro" que é a média entre uma referência
///   universal de corrida (7:00/km) e a média pessoal do próprio treino.
class PaceZoneService {
  /// Caminhada: pace igual ou pior que 12:00/km, para qualquer pessoa.
  static const int walkingPaceSecPerKm = 12 * 60;

  /// Referência universal de corrida moderada (7:00/km).
  static const int universalRunPaceSecPerKm = 7 * 60;

  /// Centro das faixas = (referência universal + média do treino) / 2.
  static const double universalMixWeight = 0.5;

  /// Muito lento: ritmo >= centro * 1.15.
  static const double slowFactor = 1.15;

  /// Acelerando: ritmo <= centro * 0.85.
  static const double fastFactor = 0.85;

  /// Distância mínima de cada trecho analisado (em metros), para suavizar
  /// o ruído do GPS sem esconder variações reais de ritmo.
  static const double chunkMinMeters = 50;

  /// Passos do degradê entre as âncoras de cor. Quantizar em passos funde
  /// trechos vizinhos de tom parecido e mantém o número de polylines baixo.
  static const int gradientSteps = 12;

  /// Suavização exponencial (0..1) aplicada apenas ao DESENHO da rota:
  /// distância, ritmo e faixas seguem calculados sobre os pontos crus.
  /// 0.35 abafa ~2/3 da tremida do GPS sem inventar curvas que não existiram.
  static const double smoothingAlpha = 0.35;

  /// Classifica um ritmo (seg/km) em uma faixa.
  static PaceZone zoneFor({
    required double paceSecPerKm,
    required double centerSecPerKm,
  }) {
    if (paceSecPerKm >= walkingPaceSecPerKm) return PaceZone.walking;
    if (paceSecPerKm >= centerSecPerKm * slowFactor) return PaceZone.slow;
    if (paceSecPerKm > 0 && paceSecPerKm <= centerSecPerKm * fastFactor) {
      return PaceZone.fast;
    }
    return PaceZone.running;
  }

  /// Centro das faixas: mix entre referência universal e média pessoal.
  static double centerSecPerKm({required double? runAvgSecPerKm}) {
    if (runAvgSecPerKm == null || runAvgSecPerKm <= 0) {
      return universalRunPaceSecPerKm.toDouble();
    }
    return universalRunPaceSecPerKm * universalMixWeight +
        runAvgSecPerKm * (1 - universalMixWeight);
  }

  /// Cor contínua do degradê para um ritmo: interpola entre as cores das
  /// faixas (caminhada → muito lento → corrida → acelerando) conforme o
  /// pace melhora, quantizada em [gradientSteps] tons discretos.
  static Color gradientColorFor({
    required double paceSecPerKm,
    required double centerSecPerKm,
  }) {
    final ramp = <Color>[
      PaceZone.walking.color,
      PaceZone.slow.color,
      PaceZone.running.color,
      PaceZone.fast.color,
    ];

    final walkingPace = walkingPaceSecPerKm.toDouble();
    // Centro degenerado (média do treino pior que caminhada): garante a
    // ordem crescente das âncoras de pace.
    final slowPace = math.min(centerSecPerKm * slowFactor, walkingPace - 1);
    final runPace = centerSecPerKm;
    final fastPace = centerSecPerKm * fastFactor;

    // t=0 → caminhada; 1/3 → muito lento; 2/3 → corrida; 1 → acelerando.
    double t;
    if (!paceSecPerKm.isFinite || paceSecPerKm <= 0) {
      t = 0; // parado ou sem dado → tom de caminhada
    } else if (paceSecPerKm >= walkingPace) {
      t = 0;
    } else if (paceSecPerKm >= slowPace) {
      t = (walkingPace - paceSecPerKm) / (walkingPace - slowPace) / 3;
    } else if (paceSecPerKm >= runPace) {
      t = 1 / 3 + (slowPace - paceSecPerKm) / (slowPace - runPace) / 3;
    } else if (paceSecPerKm >= fastPace) {
      t = 2 / 3 + (runPace - paceSecPerKm) / (runPace - fastPace) / 3;
    } else {
      t = 1;
    }

    // Quantiza em passos discretos: trechos vizinhos de tom igual fundem.
    final q = (t * gradientSteps).round() / gradientSteps;
    final scaled = q * (ramp.length - 1);
    final i = math.min(scaled.floor(), ramp.length - 2);
    return Color.lerp(ramp[i], ramp[i + 1], scaled - i)!;
  }

  /// Suavização exponencial só para desenhar: cada ponto desenhado é
  /// puxado [smoothingAlpha] na direção do GPS cru, abafando a tremida
  /// sem criar curvas que não existiram. O primeiro ponto de cada trecho
  /// fica cru para o início da linha não "pular".
  static List<LatLng> smoothedForDrawing(List<LatLng> pts) {
    if (pts.length < 3) return pts;
    final out = <LatLng>[pts.first];
    var lat = pts.first.latitude;
    var lng = pts.first.longitude;
    for (var i = 1; i < pts.length; i++) {
      final p = pts[i];
      lat += (p.latitude - lat) * smoothingAlpha;
      lng += (p.longitude - lng) * smoothingAlpha;
      out.add(LatLng(lat, lng));
    }
    return out;
  }

  /// Analisa a rota completa de um treino.
  static PaceZoneResult analyze({
    required List<List<LatLng>> route,
    required List<List<int>> routeTimes,
    required double distanceKm,
    required int durationSeconds,
    required List<RunSplit> splits,
  }) {
    if (route.isEmpty) {
      return const PaceZoneResult([], {});
    }

    final runAvg = (distanceKm > 0 && durationSeconds > 0)
        ? durationSeconds / distanceKm
        : null;
    final center = centerSecPerKm(runAvgSecPerKm: runAvg);

    final hasTimes = _timesMatchShape(route, routeTimes);

    // 1) Tempos por ponto → ritmo real por trecho.
    if (hasTimes) {
      return _analyzeWithTimes(route, routeTimes, center);
    }

    // 2) Voltas por km → ritmo por km (aproximação para treinos antigos).
    if (splits.isNotEmpty && distanceKm > 0 && durationSeconds > 0) {
      return _analyzeWithSplits(
        route: route,
        splits: splits,
        distanceKm: distanceKm,
        durationSeconds: durationSeconds,
        center: center,
      );
    }

    // 3) Sem dados de ritmo → cor única com a média do treino.
    return _uniformResult(route, center, runAvg, distanceKm);
  }

  // ── Caso 1: tempos por ponto ──────────────────────────────────────────

  static PaceZoneResult _analyzeWithTimes(
    List<List<LatLng>> route,
    List<List<int>> times,
    double center,
  ) {
    final segments = <PaceZoneSegment>[];
    final distanceByZone = <PaceZone, double>{};
    var lastZone = PaceZone.running;
    var lastColor = PaceZone.running.color;

    for (var s = 0; s < route.length; s++) {
      final points = route[s];
      final pointTimes = times[s];
      if (points.length < 2) continue;

      // Geometria de desenho suavizada; ritmo e distância usam os crus.
      final drawPts = smoothedForDrawing(points);

      // Chunks deste segmento — fundidos apenas entre si para nunca
      // desenhar uma linha por cima do hiato de uma pausa.
      final chunks = <PaceZoneSegment>[];
      var chunkStart = 0;
      var chunkDist = 0.0;

      for (var i = 1; i < points.length; i++) {
        chunkDist += _distanceMeters(points[i - 1], points[i]);

        if (chunkDist >= chunkMinMeters) {
          final chunkTime = pointTimes[i] - pointTimes[chunkStart];
          final pace = chunkTime > 0
              ? _paceSecPerKm(chunkTime, chunkDist)
              : null;
          final zone = pace != null
              ? zoneFor(paceSecPerKm: pace, centerSecPerKm: center)
              : lastZone; // tempo zerado herda a faixa anterior
          final color = pace != null
              ? gradientColorFor(paceSecPerKm: pace, centerSecPerKm: center)
              : lastColor;
          _accumulate(distanceByZone, zone, chunkDist / 1000);
          _emitSegment(
            chunks,
            zone,
            color,
            drawPts.sublist(chunkStart, i + 1),
          );
          lastZone = zone;
          lastColor = color;
          chunkStart = i;
          chunkDist = 0.0;
        }
      }

      // Resto final do segmento (trecho curto, sem 50m completos) — é o
      // que mantém a ponta da linha desenhada ao vivo na tela de corrida.
      if (points.length - 1 > chunkStart) {
        final chunkTime = pointTimes[points.length - 1] - pointTimes[chunkStart];
        final pace = chunkTime > 0
            ? _paceSecPerKm(chunkTime, chunkDist)
            : null;
        final zone = pace != null
            ? zoneFor(paceSecPerKm: pace, centerSecPerKm: center)
            : lastZone;
        final color = pace != null
            ? gradientColorFor(paceSecPerKm: pace, centerSecPerKm: center)
            : lastColor;
        _accumulate(distanceByZone, zone, chunkDist / 1000);
        _emitSegment(chunks, zone, color, drawPts.sublist(chunkStart));
      }

      segments.addAll(_mergeSegments(chunks));
    }

    return PaceZoneResult(segments, distanceByZone);
  }

  // ── Caso 2: voltas por km ─────────────────────────────────────────────

  static PaceZoneResult _analyzeWithSplits({
    required List<List<LatLng>> route,
    required List<RunSplit> splits,
    required double distanceKm,
    required int durationSeconds,
    required double center,
  }) {
    final segments = <PaceZoneSegment>[];
    final distanceByZone = <PaceZone, double>{};

    final consumedTime = splits.fold<int>(0, (sum, s) => sum + s.timeSeconds);
    final partialDist = distanceKm - splits.length;
    final partialTime = (durationSeconds - consumedTime).clamp(0, durationSeconds);
    final partialPace = partialDist > 0 && partialTime > 0
        ? partialTime / partialDist
        : null;

    double paceForCumulative(double meters) {
      final km = (meters / 1000).floor();
      if (km < splits.length) return splits[km].timeSeconds.toDouble();
      if (partialPace != null) return partialPace;
      return distanceKm > 0 ? durationSeconds / distanceKm : center;
    }

    double cumulative = 0;
    for (final points in route) {
      if (points.length < 2) continue;

      // Geometria de desenho suavizada; distâncias seguem nos crus.
      final drawPts = smoothedForDrawing(points);

      final chunks = <PaceZoneSegment>[];
      var chunkStart = 0;
      var chunkDist = 0.0;
      var chunkCumStart = cumulative;

      for (var i = 1; i < points.length; i++) {
        chunkDist += _distanceMeters(points[i - 1], points[i]);

        if (chunkDist >= chunkMinMeters) {
          final midMeters = chunkCumStart + chunkDist / 2;
          final pace = paceForCumulative(midMeters);
          final zone = zoneFor(paceSecPerKm: pace, centerSecPerKm: center);
          final color = gradientColorFor(
            paceSecPerKm: pace,
            centerSecPerKm: center,
          );
          _accumulate(distanceByZone, zone, chunkDist / 1000);
          _emitSegment(
            chunks,
            zone,
            color,
            drawPts.sublist(chunkStart, i + 1),
          );
          chunkStart = i;
          chunkCumStart += chunkDist;
          cumulative += chunkDist;
          chunkDist = 0.0;
        }
      }

      if (points.length - 1 > chunkStart) {
        final midMeters = chunkCumStart + chunkDist / 2;
        final pace = paceForCumulative(midMeters);
        final zone = zoneFor(paceSecPerKm: pace, centerSecPerKm: center);
        final color = gradientColorFor(
          paceSecPerKm: pace,
          centerSecPerKm: center,
        );
        _accumulate(distanceByZone, zone, chunkDist / 1000);
        _emitSegment(chunks, zone, color, drawPts.sublist(chunkStart));
        cumulative += chunkDist;
      }

      segments.addAll(_mergeSegments(chunks));
    }

    return PaceZoneResult(segments, distanceByZone);
  }

  // ── Caso 3: média uniforme ────────────────────────────────────────────

  static PaceZoneResult _uniformResult(
    List<List<LatLng>> route,
    double center,
    double? runAvg,
    double distanceKm,
  ) {
    final zone = runAvg != null
        ? zoneFor(paceSecPerKm: runAvg, centerSecPerKm: center)
        : PaceZone.running;
    final color = runAvg != null
        ? gradientColorFor(paceSecPerKm: runAvg, centerSecPerKm: center)
        : PaceZone.running.color;

    // Distância medida da rota (não a distância oficial do treino) para
    // que os percentuais correspondam ao que está desenhado no mapa.
    var measuredKm = 0.0;
    final segments = <PaceZoneSegment>[];
    for (final points in route) {
      if (points.length < 2) continue;
      for (var i = 1; i < points.length; i++) {
        measuredKm += _distanceMeters(points[i - 1], points[i]) / 1000;
      }
      // Um chunk por segmento da rota: sem fusão, para preservar os hiatos
      // das pausas entre segmentos.
      segments.add(PaceZoneSegment(zone, smoothedForDrawing(points), color));
    }

    final distanceByZone = <PaceZone, double>{
      if (measuredKm > 0) zone: measuredKm,
    };
    return PaceZoneResult(segments, distanceByZone);
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  static bool _timesMatchShape(List<List<LatLng>> route, List<List<int>> times) {
    if (route.isEmpty || times.length != route.length) return false;
    for (var i = 0; i < route.length; i++) {
      if (route[i].length != times[i].length) return false;
      if (route[i].length >= 2 && times[i].every((t) => t == times[i].first)) {
        return false; // todos iguais = tempos inválidos
      }
    }
    return true;
  }

  static double _paceSecPerKm(int seconds, double meters) {
    if (meters <= 0 || seconds <= 0) return double.infinity;
    return seconds / (meters / 1000);
  }

  static void _accumulate(Map<PaceZone, double> map, PaceZone zone, double km) {
    map[zone] = (map[zone] ?? 0) + km;
  }

  static void _emitSegment(
    List<PaceZoneSegment> segments,
    PaceZone zone,
    Color color,
    List<LatLng> points,
  ) {
    if (points.length < 2) return;
    segments.add(PaceZoneSegment(zone, points, color));
  }

  /// Funde trechos vizinhos do mesmo tom do degradê (reduz o número de
  /// polylines sem apagar as transições de cor).
  static List<PaceZoneSegment> _mergeSegments(List<PaceZoneSegment> input) {
    if (input.isEmpty) return input;
    final merged = <PaceZoneSegment>[input.first];
    for (var i = 1; i < input.length; i++) {
      final last = merged.last;
      final seg = input[i];
      if (last.color == seg.color &&
          last.points.isNotEmpty &&
          seg.points.isNotEmpty &&
          last.points.last == seg.points.first) {
        merged[merged.length - 1] = PaceZoneSegment(
          last.zone,
          [...last.points, ...seg.points.skip(1)],
          last.color,
        );
      } else {
        merged.add(seg);
      }
    }
    return merged;
  }

  /// Distância haversine entre dois pontos, em metros.
  static double _distanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * earthRadius * math.asin(math.sqrt(h));
  }

  static double _rad(double deg) => deg * math.pi / 180.0;
}
