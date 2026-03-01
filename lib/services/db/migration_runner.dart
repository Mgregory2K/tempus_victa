import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

typedef MigrationStep = void Function(Database db);

class MigrationRunner {
  // Backwards-compatible in-code migrations. Used only if no SQL files found.
  static final Map<int, MigrationStep> _codeMigrations = {
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

  /// Apply migrations. If [migrationsDir] contains SQL files named `V{n}__desc.sql` they
  /// will be applied in numeric order. Otherwise falls back to in-code migrations.
  ///
  /// [migrationsDir] is relative to the process cwd by default and can be overridden
  /// for tests or platform-specific packaging.
  static void applyMigrations(Database db,
      {String migrationsDir = 'migrations/sql'}) {
    // read current user_version
    final res = db.select('PRAGMA user_version');
    int current = 0;
    if (res.isNotEmpty) {
      final row = res.first;
      current = row['user_version'] as int? ?? 0;
    }

    // Try to load SQL files from migrationsDir
    final dir = Directory(migrationsDir);
    if (dir.existsSync()) {
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) =>
              RegExp(r'V(\d+)__.*\.sql').hasMatch(f.uri.pathSegments.last))
          .toList();

      final parsed = <int, File>{};
      for (final f in files) {
        final name = f.uri.pathSegments.last;
        final m = RegExp(r'^V(\d+)__').firstMatch(name);
        if (m == null) continue;
        final v = int.tryParse(m.group(1)!) ?? 0;
        if (v > 0) parsed[v] = f;
      }

      final versions = parsed.keys.toList()..sort();
      for (final v in versions) {
        if (v <= current) continue;
        final f = parsed[v]!;
        final sql = f.readAsStringSync();
        db.execute('BEGIN TRANSACTION');
        try {
          // execute potentially multi-statement SQL;
          // sqlite3 Dart package accepts multiple statements separated by ';'
          for (final stmt in sql.split(RegExp(r';\s*'))) {
            final s = stmt.trim();
            if (s.isEmpty) continue;
            db.execute(s);
          }
          db.execute('PRAGMA user_version = $v');
          db.execute('COMMIT');
        } catch (e) {
          db.execute('ROLLBACK');
          rethrow;
        }
      }
      return;
    }

    // Fallback to code migrations
    final target = _codeMigrations.keys.isEmpty
        ? current
        : _codeMigrations.keys.reduce((a, b) => a > b ? a : b);
    for (int v = current + 1; v <= target; v++) {
      final step = _codeMigrations[v];
      if (step == null) continue;
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
