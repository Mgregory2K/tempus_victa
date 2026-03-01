import 'dart:io';

import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tempus_victa/services/db/migration_runner.dart';

void main() {
  test('SQL-file migrations are applied in order', () {
    final tmp = Directory.systemTemp.createTempSync('tv_mig_test');
    final migrationsDir = Directory('${tmp.path}/migrations_sql')..createSync(recursive: true);

    // create a simple V3 migration file
    final f = File('${migrationsDir.path}/V3__create_test_table.sql');
    f.writeAsStringSync('''
      CREATE TABLE IF NOT EXISTS test_table (
        id TEXT PRIMARY KEY,
        v INTEGER
      );
    ''');

    final dbFile = File('${tmp.path}/test.db');
    if (dbFile.existsSync()) dbFile.deleteSync();
    final db = sqlite3.open(dbFile.path);
    db.execute('PRAGMA user_version = 1');

    // apply migrations from our temporary dir
    MigrationRunner.applyMigrations(db, migrationsDir: migrationsDir.path);

    final res = db.select('PRAGMA user_version');
    final v = res.first['user_version'] as int;
    expect(v, greaterThanOrEqualTo(3));

    final tables = db.select("SELECT name FROM sqlite_master WHERE type='table' AND name='test_table'");
    expect(tables.isNotEmpty, isTrue);

    db.dispose();
    tmp.deleteSync(recursive: true);
  });
}
