/// Efeitos de sistema disparados pelo motor da corrida.
///
/// Ficam atrás de uma porta para que o controller possa ser testado sem
/// plugins, analytics, notificações ou hardware.
abstract interface class RunSessionEffects {
  Future<void> setWakeLock(bool enabled);

  Future<void> logRunStarted(String runType);

  Future<void> notifyKm(int km, String pace);

  Future<void> autoPauseStarted();

  Future<void> autoPauseResumed();

  Future<void> pacingStatusChanged();
}
