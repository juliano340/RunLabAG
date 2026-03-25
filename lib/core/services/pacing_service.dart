import 'dart:collection';

enum PacingStatus { 
  behind,   // Mais lento que a meta (precisa acelerar)
  ahead,    // Mais rápido que a meta (pode reduzir)
  onTrack,  // Dentro da zona alvo
  none      // Sem meta definida
}

class PacingFeedback {
  final PacingStatus status;
  final String message;
  final String idealPace;   // Formatado como MM:SS
  final String currentPace; // Formatado como MM:SS
  final double progress;    // 0.0 a 1.0 da meta de distância

  PacingFeedback({
    required this.status,
    required this.message,
    required this.idealPace,
    required this.currentPace,
    required this.progress,
  });
}

class PacePoint {
  final double distance;
  final DateTime timestamp;

  PacePoint(this.distance, this.timestamp);
}

class PacingService {
  final double? targetDistanceKm;
  final int? targetTimeSeconds;
  
  // Buffer para média móvel (últimos 15-20 segundos)
  final Queue<PacePoint> _buffer = Queue<PacePoint>();
  final int _bufferWindowSeconds = 15;
  
  // Tolerância de pace para evitar feedback excessivo (segundos por km)
  final int _paceToleranceSeconds = 10;

  PacingService({this.targetDistanceKm, this.targetTimeSeconds});

  /// Calcula o pace ideal (segundos por km)
  int? get idealPaceSeconds {
    if (targetDistanceKm == null || targetTimeSeconds == null || targetDistanceKm! <= 0) return null;
    return (targetTimeSeconds! / targetDistanceKm!).round();
  }

  /// Formata segundos para MM:SS
  String _formatPace(int secondsPerKm) {
    if (secondsPerKm <= 0 || secondsPerKm > 3600) return "--:--";
    final minutes = (secondsPerKm / 60).floor();
    final seconds = secondsPerKm % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Adiciona um ponto de dados e retorna o feedback atualizado
  PacingFeedback? getUpdate(double currentDistanceKm, int elapsedSeconds) {
    if (targetDistanceKm == null || idealPaceSeconds == null) return null;

    final now = DateTime.now();
    _buffer.add(PacePoint(currentDistanceKm, now));

    // Limpa pontos antigos fora da janela de buffer
    while (_buffer.isNotEmpty && 
           now.difference(_buffer.first.timestamp).inSeconds > _bufferWindowSeconds) {
      _buffer.removeFirst();
    }

    // Calcula pace atual suavizado baseado no buffer
    int currentPaceSeconds = 0;
    if (_buffer.length >= 2) {
      final distDiff = _buffer.last.distance - _buffer.first.distance;
      final timeDiff = _buffer.last.timestamp.difference(_buffer.first.timestamp).inSeconds;
      
      if (distDiff > 0.005) { // Mínimo de 5 metros para calcular um pace estável
        currentPaceSeconds = (timeDiff / distDiff).round();
      }
    }

    // Se o buffer for insuficiente, usa o pace médio total como fallback temporário
    if (currentPaceSeconds == 0 && currentDistanceKm > 0.01) {
      currentPaceSeconds = (elapsedSeconds / currentDistanceKm).round();
    }

    final status = _determineStatus(currentPaceSeconds);
    final message = _getMessage(status);
    final progress = (currentDistanceKm / targetDistanceKm!).clamp(0.0, 1.0);

    return PacingFeedback(
      status: status,
      message: message,
      idealPace: _formatPace(idealPaceSeconds!),
      currentPace: _formatPace(currentPaceSeconds),
      progress: progress,
    );
  }

  PacingStatus _determineStatus(int currentPaceSeconds) {
    final target = idealPaceSeconds;
    if (target == null || currentPaceSeconds <= 0) return PacingStatus.none;

    // Diferença em segundos: pace maior significa que está mais lento
    final diff = currentPaceSeconds - target;

    if (diff > _paceToleranceSeconds) {
      return PacingStatus.behind; // Está mais lento que o alvo + tolerância
    } else if (diff < -_paceToleranceSeconds) {
      return PacingStatus.ahead; // Está mais rápido que o alvo - tolerância
    } else {
      return PacingStatus.onTrack;
    }
  }

  String _getMessage(PacingStatus status) {
    switch (status) {
      case PacingStatus.behind:
        return "Você está abaixo do pace. Acelere um pouco! ⚡";
      case PacingStatus.ahead:
        return "Você está acima da meta. Pode reduzir o ritmo. 🧘";
      case PacingStatus.onTrack:
        return "Ritmo perfeito! Mantenha assim. 🎯";
      case PacingStatus.none:
        return "Aquecendo... mantenha o foco!";
    }
  }
}
