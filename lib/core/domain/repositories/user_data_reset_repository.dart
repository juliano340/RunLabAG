abstract interface class UserDataResetRepository {
  /// Remove dados do usuário e restaura catálogos/configurações padrão.
  Future<void> resetAllData();
}
