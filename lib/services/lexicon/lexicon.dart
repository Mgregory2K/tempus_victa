import 'dart:convert';
import '../db/db_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class LexiconEntry {
  final String phrase;
  final int count;
  final String? lastSeen;
  final double score;
  final Map<String, dynamic>? metadata;

  LexiconEntry(
      {required this.phrase,
      required this.count,
      this.lastSeen,
      required this.score,
      this.metadata});
}

class LexiconService {
  static PreparedStatement? _selectCountStmt;
  static PreparedStatement? _insertStmt;
  static PreparedStatement? _updateStmt;
  static PreparedStatement? _suggestStmt;

  static void _ensureStatements() {
    final db = DatabaseProvider.instance;
    _selectCountStmt ??=
        db.prepare('SELECT count FROM lexicon_entries WHERE phrase = ?');
    _insertStmt ??= db.prepare(
        'INSERT INTO lexicon_entries (phrase,count,last_seen,score) VALUES (?,?,?,?)');
    _updateStmt ??= db.prepare(
        'UPDATE lexicon_entries SET count = ?, last_seen = ?, score = ? WHERE phrase = ?');
    _suggestStmt ??= db.prepare(
        'SELECT phrase,count,last_seen,score,metadata FROM lexicon_entries WHERE phrase LIKE ? ORDER BY score DESC, count DESC LIMIT ?');
  }

  /// Increment phrase occurrence and update score.
  static void observePhrase(String phrase) {
    _ensureStatements();
    final db = DatabaseProvider.instance;
    final now = DateTime.now().toUtc().toIso8601String();

    final rows = _selectCountStmt!.select([phrase]);

    if (rows.isEmpty) {
      _insertStmt!.execute([phrase, 1, now, 1.0]);
      return;
    }

    final current = rows.first['count'] as int? ?? 0;
    final next = current + 1;
    final score = (next / (next + 5)).clamp(0.0, 1.0);
    _updateStmt!.execute([next, now, score, phrase]);
  }

  /// Suggest phrases by prefix, ordered by score desc then count.
  static List<LexiconEntry> suggest(String prefix, {int limit = 8}) {
    _ensureStatements();
    final rows = _suggestStmt!.select(['${prefix}%', limit]);
    return rows.map((r) {
      Map<String, dynamic>? meta;
      if (r['metadata'] != null) {
        try {
          meta = jsonDecode(r['metadata'] as String) as Map<String, dynamic>;
        } catch (_) {
          meta = null;
        }
      } else {
        meta = null;
      }
      return LexiconEntry(
          phrase: r['phrase'] as String,
          count: r['count'] as int,
          lastSeen: r['last_seen'] as String?,
          score: (r['score'] as num).toDouble(),
          metadata: meta);
    }).toList(growable: false);
  }

  /// Dispose cached prepared statements. Call on shutdown if needed.
  static void close() {
    _selectCountStmt?.dispose();
    _insertStmt?.dispose();
    _updateStmt?.dispose();
    _suggestStmt?.dispose();
    _selectCountStmt = null;
    _insertStmt = null;
    _updateStmt = null;
    _suggestStmt = null;
  }
}
