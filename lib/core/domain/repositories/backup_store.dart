import '../models/backup_snapshot.dart';

/// Porta de acesso aos dados incluídos no backup.
///
/// A implementação conhece o schema; o serviço de arquivo não conhece.
abstract interface class BackupStore {
  Future<BackupSnapshot> readSnapshot();

  Future<String?> getCurrentProfilePhotoPath();

  Future<void> restoreSnapshot(
    BackupSnapshot snapshot, {
    String? restoredPhotoPath,
  });
}
