/// Snapshot versionado dos dados persistidos no backup.
class BackupSnapshot {
  static const currentVersion = 4;

  final int version;
  final DateTime exportedAt;
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> runs;

  /// Tabelas auxiliares presentes no arquivo. A ausência de uma chave é
  /// preservada para que backups antigos continuem importáveis.
  final Map<String, List<Map<String, dynamic>>> tables;

  const BackupSnapshot({
    required this.version,
    required this.exportedAt,
    required this.profile,
    required this.runs,
    required this.tables,
  });

  factory BackupSnapshot.fromJson(Map<String, dynamic> json) {
    final tables = <String, List<Map<String, dynamic>>>{};
    for (final entry in json.entries) {
      if (entry.key == 'version' ||
          entry.key == 'exportedAt' ||
          entry.key == 'profile' ||
          entry.key == 'runs') {
        continue;
      }
      final value = entry.value;
      if (value is! List) continue;
      tables[entry.key] = [
        for (final row in value)
          if (row is Map) Map<String, dynamic>.from(row),
      ];
    }

    final runs = json['runs'];
    return BackupSnapshot(
      version: (json['version'] as num?)?.toInt() ?? 1,
      exportedAt:
          DateTime.tryParse('${json['exportedAt']}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      profile: json['profile'] is Map
          ? Map<String, dynamic>.from(json['profile'] as Map)
          : null,
      runs: runs is List
          ? [
              for (final row in runs)
                if (row is Map) Map<String, dynamic>.from(row),
            ]
          : const [],
      tables: tables,
    );
  }

  BackupSnapshot copyWith({Map<String, dynamic>? profile}) {
    return BackupSnapshot(
      version: currentVersion,
      exportedAt: exportedAt,
      profile: profile ?? this.profile,
      runs: runs,
      tables: tables,
    );
  }

  Map<String, dynamic> toJson({Map<String, dynamic>? profile}) {
    return {
      'version': currentVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'profile': profile ?? this.profile,
      'runs': runs,
      ...tables,
    };
  }
}
