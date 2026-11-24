import '../models/run_model.dart';

/// Confirmação atômica de um treino concluído.
abstract interface class RunCompletionStore {
  Future<void> saveCompletedRun({
    required RunModel run,
    required Map<String, double> distanceByZone,
  });
}
