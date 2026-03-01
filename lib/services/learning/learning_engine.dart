import 'package:tempus_victa/services/lexicon/lexicon.dart';
import 'package:tempus_victa/services/db/db_provider.dart';

class LearningEngine {
  /// Process a feedback event (e.g., promoted, opened, recycled) and update
  /// lightweight learning artifacts: lexicon and trust_scores.
  static void processFeedback({required String subject, required String event, String? phrase}) {
    final db = DatabaseProvider.instance;
    final now = DateTime.now().toIso8601String();

    // Update trust_scores: simple bump/deduct heuristics
    final cur = db.select('SELECT score FROM trust_scores WHERE subject = ?', [subject]);
    double score = 0.5;
    if (cur.isNotEmpty) score = (cur.first['score'] as num).toDouble();

    if (event == 'promoted') score = (score + 0.08).clamp(0.0, 1.0);
    if (event == 'opened') score = (score + 0.02).clamp(0.0, 1.0);
    if (event == 'recycled') score = (score - 0.06).clamp(0.0, 1.0);
    if (event == 'muted') score = (score - 0.2).clamp(0.0, 1.0);

    db.execute('INSERT OR REPLACE INTO trust_scores (subject,score,last_updated) VALUES (?,?,?)', [subject, score, now]);

    // Update lexicon if phrase provided
    if (phrase != null && phrase.trim().isNotEmpty) {
      LexiconService.observePhrase(phrase.trim().toLowerCase());
    }
  }
}
