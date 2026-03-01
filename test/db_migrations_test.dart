import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tempus_victa/services/db/migration_runner.dart';

void main() {
  test('Apply migrations upgrades user_version and creates drafts table', () {
    final db = sqlite3.openInMemory();
    // set current version to 1
    db.execute('PRAGMA user_version = 1');
    final res1 = db.select('PRAGMA user_version');
    final v1 = res1.first['user_version'] as int;
    expect(v1, equals(1));

    // Apply migrations
    MigrationRunner.applyMigrations(db);

    final res2 = db.select('PRAGMA user_version');
    final v2 = res2.first['user_version'] as int;
    expect(v2, greaterThanOrEqualTo(2));

    // check drafts table exists
    final tables = db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='drafts'");
    expect(tables.isNotEmpty, isTrue);

    db.dispose();
  });
}
