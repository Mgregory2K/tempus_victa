import 'dart:convert';
import 'package:tempus_victa/services/db/db_provider.dart';

class LexiconEntry {
  final String phrase;
  final int count;
  final String? lastSeen;
  final double score;
  final Map<String, dynamic>? metadata;

  LexiconEntry({required this.phrase, required this.count, this.lastSeen, required this.score, this.metadata});
}

class LexiconService {
  /// Increment phrase occurrence and update score.
  static void observePhrase(String phrase) {
    final db = DatabaseProvider.instance;
    final now = DateTime.now().toIso8601String();
    final stmt = db.prepare('SELECT count FROM lexicon_entries WHERE phrase = ?');
    final rows = stmt.select([phrase]);
    stmt.dispose();

    if (rows.isEmpty) {
      final ins = db.prepare('INSERT INTO lexicon_entries (phrase,count,last_seen,score) VALUES (?,?,?,?)');
      ins.execute([phrase, 1, now, 1.0]);
      ins.dispose();
      return;
    }

    final current = rows.first['count'] as int? ?? 0;
    final next = current + 1;
    final score = (next / (next + 5)).clamp(0.0, 1.0);
    final upd = db.prepare('UPDATE lexicon_entries SET count = ?, last_seen = ?, score = ? WHERE phrase = ?');
    upd.execute([next, now, score, phrase]);
    upd.dispose();
  }

  /// Suggest phrases by prefix, ordered by score desc then count.
  static List<LexiconEntry> suggest(String prefix, {int limit = 8}) {
    final db = DatabaseProvider.instance;
    final rows = db.select('SELECT phrase,count,last_seen,score,metadata FROM lexicon_entries WHERE phrase LIKE ? ORDER BY score DESC, count DESC LIMIT ?', ['${prefix}%', limit]);
    return rows.map((r) {
      final meta = r['metadata'] != null ? jsonDecode(r['metadata'] as String) as Map<String, dynamic> : null;
      return LexiconEntry(phrase: r['phrase'] as String, count: r['count'] as int, lastSeen: r['last_seen'] as String?, score: (r['score'] as num).toDouble(), metadata: meta);
    }).toList(growable: false);
  }
}
