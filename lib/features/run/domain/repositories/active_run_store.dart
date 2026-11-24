/// Persistência do treino em andamento, sem expor sqflite ao controller.
abstract interface class ActiveRunStore {
  Future<void> saveMeta(Map<String, dynamic> data);

  Future<void> saveRoute(String routeJson);

  Future<void> clear();
}
