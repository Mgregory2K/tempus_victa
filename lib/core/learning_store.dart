import '../data/db/corkboard_db.dart';
import 'signal_item.dart';

/// Local-first learning signals about how the user treats incoming signals.
/// This is NOT AI. It's deterministic behavioral learning (counts + ratios),
/// used to suggest automation rules (mute, auto-pin, auto-promote) later.
class LearningStore {
  static Future<void> ensureSchema() async {
    final db = await CorkboardDb.instance();
    db.execute('''
      CREATE TABLE IF NOT EXISTS learning_signal_actions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fingerprint TEXT NOT NULL,
        source TEXT NOT NULL,
        action TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL
      );
    ''');
    db.execute('CREATE INDEX IF NOT EXISTS idx_learning_fingerprint ON learning_signal_actions(fingerprint);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_learning_source ON learning_signal_actions(source);');
  }

  static Future<void> recordSignalAction(SignalItem s, String action) async {
    await ensureSchema();
    final db = await CorkboardDb.instance();
    final stmt = db.prepare(
      'INSERT INTO learning_signal_actions (fingerprint, source, action, created_at_ms) VALUES (?, ?, ?, ?)',
    );
    try {
      stmt.execute([s.fingerprint, s.source, action, DateTime.now().millisecondsSinceEpoch]);
    } finally {
      stmt.dispose();
    }
  }

  /// Returns map[source] -> map[action] -> count
  static Future<Map<String, Map<String, int>>> summarizeBySource({int days = 30}) async {
    await ensureSchema();
    final db = await CorkboardDb.instance();
    final sinceMs = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final rs = db.select(
      'SELECT source, action, COUNT(*) as c FROM learning_signal_actions WHERE created_at_ms >= ? GROUP BY source, action',
      [sinceMs],
    );
    final out = <String, Map<String, int>>{};
    for (final row in rs) {
      final source = row['source'] as String? ?? 'unknown';
      final action = row['action'] as String? ?? 'unknown';
      final c = (row['c'] as int?) ?? 0;
      out.putIfAbsent(source, () => <String, int>{});
      out[source]![action] = c;
    }
    return out;
  }

  /// Returns top fingerprints with promote/recycle/pin counts.
  static Future<List<Map<String, Object?>>> topFingerprints({int limit = 20, int days = 30}) async {
    await ensureSchema();
    final db = await CorkboardDb.instance();
    final sinceMs = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final rs = db.select(
      '''
      SELECT fingerprint, source,
        SUM(CASE WHEN action='promote_task' THEN 1 ELSE 0 END) as promote_task,
        SUM(CASE WHEN action='pin_cork' THEN 1 ELSE 0 END) as pin_cork,
        SUM(CASE WHEN action='recycle' THEN 1 ELSE 0 END) as recycle,
        SUM(CASE WHEN action='ack' THEN 1 ELSE 0 END) as ack,
        COUNT(*) as total
      FROM learning_signal_actions
      WHERE created_at_ms >= ?
      GROUP BY fingerprint, source
      ORDER BY total DESC
      LIMIT ?
      ''',
      [sinceMs, limit],
    );
    return rs.map((row) => row.cast<String, Object?>()).toList(growable: false);
  }
}
