// Tempus Victa - generated 2026-02-21
// Local-first, Android-first. Billion-dollar architecture starts here.
//
// DB Doctrine:
// - Everything is a Signal first.
// - Everything is timestamped (captured/created/modified UTC).
// - Learning is stored locally as weights + event log.
// - Automation is gated by confidence thresholds (stored locally).

import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  Database? _db;

  // Defensive schema enforcement.
  // In the wild, you may have an older DB file with a partial schema even if the version matches.
  // We fix that by introspecting table_info and adding missing columns safely.
  Future<void> _ensureSchema(Database db) async {
    await _ensureSignalsColumns(db);
    await _ensureMetaColumns(db);
    // Add other table guards here if we evolve schema again.
  }

  Future<void> _ensureSignalsColumns(Database db) async {
    final cols = await _tableColumns(db, 'signals');
    // If the table doesn't exist yet, onCreate will handle it.
    if (cols.isEmpty) return;

    // Minimal required columns for runtime queries.
    await _addColumnIfMissing(db, 'signals', cols, 'status', "TEXT DEFAULT 'inbox'");
    await _addColumnIfMissing(db, 'signals', cols, 'source', "TEXT");
    await _addColumnIfMissing(db, 'signals', cols, 'captured_at_utc', "INTEGER");
    await _addColumnIfMissing(db, 'signals', cols, 'created_at_utc', "INTEGER");
    await _addColumnIfMissing(db, 'signals', cols, 'modified_at_utc', "INTEGER");
    await _addColumnIfMissing(db, 'signals', cols, 'confidence', "REAL DEFAULT 0");
    await _addColumnIfMissing(db, 'signals', cols, 'weight', "REAL DEFAULT 0");
  }

  Future<void> _ensureMetaColumns(Database db) async {
    final cols = await _tableColumns(db, 'meta');
    if (cols.isEmpty) return;
    await _addColumnIfMissing(db, 'meta', cols, 'updated_at_utc', "INTEGER");
  }

  Future<Set<String>> _tableColumns(Database db, String table) async {
    try {
      final rows = await db.rawQuery('PRAGMA table_info($table)');
      return rows.map((r) => (r['name'] as String?)?.toLowerCase() ?? '').where((s) => s.isNotEmpty).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    Set<String> colsLower,
    String columnName,
    String columnDefSql,
  ) async {
    if (colsLower.contains(columnName.toLowerCase())) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $columnName $columnDefSql;');
  }


  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'tempus_victa.db');

    final database = await openDatabase(
      path,
      version: 3,
      onCreate: (d, _) async => _createOrUpgrade(d),
      onUpgrade: (d, oldV, newV) async => _createOrUpgrade(d),
    );

    await _ensureSchema(database);

    _db = database;
    return database;
  }

  Future<void> _createOrUpgrade(Database d) async {
    await d.execute('''
CREATE TABLE IF NOT EXISTS meta(
  k TEXT PRIMARY KEY,
  v TEXT,
  updated_at_utc INTEGER
);
''');

    await d.execute('''
CREATE TABLE IF NOT EXISTS signals(
  id TEXT PRIMARY KEY,
  kind TEXT,              -- e.g. voice,text,notification,calendar,email
  text TEXT,              -- original text input (if any)
  transcript TEXT,        -- voice transcript (if any)
  source TEXT,            -- bridge_voice, bridge_text, ready_room, etc.
  status TEXT,            -- inbox, task, corkboard, project, recycle, archived
  confidence REAL,        -- 0..1 confidence for any auto-routing
  weight REAL,            -- importance/priority weight (learned)
  captured_at_utc INTEGER,
  created_at_utc INTEGER,
  modified_at_utc INTEGER
);
''');

    await d.execute('''
CREATE TABLE IF NOT EXISTS recycle(
  id TEXT PRIMARY KEY,
  signal_id TEXT,
  reason TEXT,
  deleted_at_utc INTEGER
);
''');

    await d.execute('''
CREATE TABLE IF NOT EXISTS tasks(
  id TEXT PRIMARY KEY,
  title TEXT,
  details TEXT,
  status TEXT,            -- open, done, snoozed
  source TEXT,
  signal_id TEXT,
  due_at_utc INTEGER,
  captured_at_utc INTEGER,
  created_at_utc INTEGER,
  modified_at_utc INTEGER,
  value_score REAL,       -- learned
  effort_score REAL       -- learned
);
''');

    await d.execute('''
CREATE TABLE IF NOT EXISTS projects(
  id TEXT PRIMARY KEY,
  title TEXT,
  status TEXT,            -- active, done
  created_at_utc INTEGER,
  modified_at_utc INTEGER
);
''');

    await d.execute('''
CREATE TABLE IF NOT EXISTS cork_notes(
  id TEXT PRIMARY KEY,
  text TEXT,
  created_at_utc INTEGER,
  modified_at_utc INTEGER
);
''');

    await d.execute('''
CREATE TABLE IF NOT EXISTS learning_weights(
  k TEXT PRIMARY KEY,     -- e.g. route:bridge_voice->task
  v REAL,
  updated_at_utc INTEGER
);
''');

    await d.execute('''
CREATE TABLE IF NOT EXISTS learning_events(
  id TEXT PRIMARY KEY,
  event_type TEXT,        -- route, dismiss, complete, edit, ai_classify, etc.
  entity_type TEXT,       -- signal, task, project
  entity_id TEXT,
  source TEXT,
  payload_json TEXT,
  score_delta REAL,
  occurred_at_utc INTEGER
);
''');

    await d.execute('''
CREATE TABLE IF NOT EXISTS lexicon(
  phrase TEXT PRIMARY KEY,
  intent TEXT,
  weight REAL,
  updated_at_utc INTEGER
);
''');

    await d.execute('''
CREATE TABLE IF NOT EXISTS automation_rules(
  id TEXT PRIMARY KEY,
  name TEXT,
  enabled INTEGER,
  trigger_json TEXT,
  action_json TEXT,
  confidence_threshold REAL,
  created_at_utc INTEGER,
  modified_at_utc INTEGER
);
''');
      // Ensure any missing columns are added for existing installs.
    await _ensureSchema(d);
}

  // ---------- Meta KV ----------
  Future<String?> getMeta(String key) async {
    final d = await db;
    final rows = await d.query('meta', where: 'k = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['v'] as String?;
  }

  Future<void> setMeta(String key, String value) async {
    final d = await db;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await d.insert(
      'meta',
      {'k': key, 'v': value, 'updated_at_utc': now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteMeta(String key) async {
    final d = await db;
    await d.delete('meta', where: 'k = ?', whereArgs: [key]);
  }

  // ---------- Learning weights ----------
  Future<double> getWeight(String key, {double defaultValue = 0}) async {
    final d = await db;
    final rows = await d.query('learning_weights', where: 'k = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return defaultValue;
    final v = rows.first['v'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? defaultValue;
  }

  Future<void> setWeight(String key, double value) async {
    final d = await db;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await d.insert(
      'learning_weights',
      {'k': key, 'v': value, 'updated_at_utc': now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------- Learning events ----------
  Future<void> addLearningEvent(Map<String, Object?> row) async {
    final d = await db;
    await d.insert('learning_events', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
