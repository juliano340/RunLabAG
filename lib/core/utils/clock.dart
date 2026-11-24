import 'dart:async';

/// Relógio injetável para tornar timer, timestamps e throttles testáveis.
abstract interface class Clock {
  DateTime now();

  Timer periodic(Duration interval, void Function(Timer timer) callback);
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();

  @override
  Timer periodic(Duration interval, void Function(Timer timer) callback) {
    return Timer.periodic(interval, callback);
  }
}
