import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

class BackupService {
  final DatabaseService _dbService = DatabaseService();

  Future<void> exportBackup() async {
    try {
      final db = await _dbService.database;
      
      // Fetch all data
      final profileData = await db.query('user_profile');
      final runsData = await db.query('runs');
      
      final Map<String, dynamic> backup = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'profile': profileData.isNotEmpty ? profileData.first : null,
        'runs': runsData,
      };
      
      final String jsonString = jsonEncode(backup);
      
      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/runlab_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);
      
      // Share file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Backup RunLab - ${DateTime.now().day}/${DateTime.now().month}',
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> importBackup(String jsonContent) async {
    try {
      final Map<String, dynamic> backup = jsonDecode(jsonContent);
      final db = await _dbService.database;
      
      await db.transaction((txn) async {
        // Restore Profile
        if (backup['profile'] != null) {
          await txn.insert(
            'user_profile',
            backup['profile'],
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        
        // Restore Runs
        if (backup['runs'] != null) {
          final List<dynamic> runs = backup['runs'];
          for (final run in runs) {
            await txn.insert(
              'runs',
              run,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      });
      
      return true;
    } catch (e) {
      return false;
    }
  }
}
