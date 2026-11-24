import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/core/services/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseHelper.databaseFileName = 'runlab_open_test.db';
    final path =
        '${await databaseFactory.getDatabasesPath()}/runlab_open_test.db';
    await databaseFactory.deleteDatabase(path);
    DatabaseHelper.resetForTest();
  });

  tearDown(() async {
    final db = await DatabaseHelper.database;
    await db.close();
    DatabaseHelper.resetForTest();
    DatabaseHelper.databaseFileName = 'runlab_database.db';
  });

  test('chamadas concorrentes compartilham a mesma abertura', () async {
    final databases = await Future.wait([
      for (var i = 0; i < 20; i++) DatabaseHelper.database,
    ]);

    for (final database in databases.skip(1)) {
      expect(identical(databases.first, database), isTrue);
    }
  });
}
