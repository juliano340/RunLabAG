/// Persistência do treino ativo. Metadados e rota continuam separados.
abstract interface class ActiveRunRepository {
  Future<void> saveActiveRunMeta(Map<String, dynamic> data);

  Future<void> saveActiveRunRoute(String routeJson);

  Future<Map<String, dynamic>?> getActiveRunMeta();

  Future<Map<String, dynamic>?> getActiveRun();

  Future<void> clearActiveRun();
}
