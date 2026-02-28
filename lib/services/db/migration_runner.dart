import 'package:sqlite3/sqlite3.dart';

typedef MigrationStep = void Function(Database db);

class MigrationRunner {
  // Map migrations by target version. Each migration should bring DB to that version.
  static final Map<int, MigrationStep> _migrations = {
    // v2: add drafts table to store inline edit drafts (optional helper)
    2: (Database db) {
      db.execute('''
        CREATE TABLE IF NOT EXISTS drafts (
          prov_id TEXT PRIMARY KEY,
          overrides TEXT,
          updated_at TEXT
        );
      ''');
    },
  };

  /// Apply all migrations greater than the current PRAGMA user_version.
  static void applyMigrations(Database db) {
    final res = db.select('PRAGMA user_version');
    int current = 0;
    if (res.isNotEmpty) {
      final row = res.first;
      current = row['user_version'] as int? ?? 0;
    }

    final target = _migrations.keys.isEmpty ? current : _migrations.keys.reduce((a, b) => a > b ? a : b);
    for (int v = current + 1; v <= target; v++) {
      final step = _migrations[v];
      if (step == null) continue;
      // run in transaction
      db.execute('BEGIN TRANSACTION');
      try {
        step(db);
        db.execute('PRAGMA user_version = $v');
        db.execute('COMMIT');
      } catch (e) {
        db.execute('ROLLBACK');
        rethrow;
      }
    }
  }
}
