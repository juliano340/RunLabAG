/// Situação persistida do último backup automático.
///
/// Mantém a UI livre de chaves de SharedPreferences e permite distinguir
/// sucesso total, sucesso parcial e falha sem depender de `Map<String, dynamic>`.
class BackupStatus {
  final DateTime? lastSuccessfulBackupAt;
  final DateTime? lastAttemptAt;
  final String? lastError;
  final int successfulCopies;
  final int attemptedCopies;

  const BackupStatus({
    this.lastSuccessfulBackupAt,
    this.lastAttemptAt,
    this.lastError,
    this.successfulCopies = 0,
    this.attemptedCopies = 0,
  });

  bool get hasBackup => lastSuccessfulBackupAt != null;
  bool get hasError => lastError != null && lastError!.isNotEmpty;
  bool get isPartialSuccess => successfulCopies > 0 && hasError;

  bool isStaleAt(DateTime now, {Duration maxAge = const Duration(days: 7)}) {
    final lastBackup = lastSuccessfulBackupAt;
    if (lastBackup == null) return false;
    return now.difference(lastBackup) > maxAge;
  }
}
