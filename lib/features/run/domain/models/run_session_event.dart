import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Eventos do motor que a UI converte em snackbars e movimento de câmera.
sealed class RunSessionEvent {}

class RunLocationReady extends RunSessionEvent {
  final LatLng position;

  RunLocationReady(this.position);
}

class RunPositionUpdated extends RunSessionEvent {
  final LatLng position;

  RunPositionUpdated(this.position);
}

class RunAutoPauseStarted extends RunSessionEvent {}

class RunAutoPauseResumed extends RunSessionEvent {}

class RunKilometerReached extends RunSessionEvent {
  final int kilometer;
  final String message;

  RunKilometerReached(this.kilometer, this.message);
}

class RunSessionError extends RunSessionEvent {
  final String message;

  RunSessionError(this.message);
}
