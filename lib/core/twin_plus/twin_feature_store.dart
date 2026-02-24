import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'twin_event.dart';
import 'twin_preference_ledger.dart';

class TwinFeatureStore {
  final File _file;
  final TwinPreferenceLedger prefs;

  /// Simple lexicon stats.
  final Map<String, int> tokenCounts = <String, int>{};

  /// Style signature (cheap metrics).
  double avgWords = 0.0;
  double avgPunctDensity = 0.0;
  double capsRate = 0.0;
  double profanityRate = 0.0;

  int _samples = 0;

  TwinFeatureStore._(this._file, {required this.prefs});

  static Future<TwinFeatureStore> open({required TwinPreferenceLedger prefs}) async {
    final dir = await getApplicationDocumentsDirectory();
    final tp = Directory(p.join(dir.path, 'twin_plus'));
    if (!tp.existsSync()) tp.createSync(recursive: true);
    final f = File(p.join(tp.path, 'features.json'));
    final store = TwinFeatureStore._(f, prefs: prefs);
    await store._load();
    return store;
  }

  Future<void> _load() async {
    if (!_file.existsSync()) return;
    try {
      final raw = await _file.readAsString();
      final j = jsonDecode(raw);
      if (j is! Map) return;

      final tc = j['tokenCounts'];
      if (tc is Map) {
        for (final e in tc.entries) {
          final k = e.key.toString();
          final v = (e.value is num) ? (e.value as num).toInt() : int.tryParse(e.value.toString()) ?? 0;
          if (k.isNotEmpty && v > 0) tokenCounts[k] = v;
        }
      }
      avgWords = _asDouble(j['avgWords']);
      avgPunctDensity = _asDouble(j['avgPunctDensity']);
      capsRate = _asDouble(j['capsRate']);
      profanityRate = _asDouble(j['profanityRate']);
      _samples = (j['_samples'] is int) ? (j['_samples'] as int) : int.tryParse(j['_samples']?.toString() ?? '') ?? 0;
    } catch (_) {}
  }

  Future<void> persist() async {
    final j = <String, dynamic>{
      'tokenCounts': tokenCounts,
      'avgWords': avgWords,
      'avgPunctDensity': avgPunctDensity,
      'capsRate': capsRate,
      'profanityRate': profanityRate,
      '_samples': _samples,
    };
    await _file.writeAsString(jsonEncode(j), flush: true);
  }

  void apply(TwinEvent e) {
    if (e.type == TwinEventType.textSubmitted) {
      final text = (e.payload['text'] ?? '').toString();
      final words = (e.payload['words'] is num) ? (e.payload['words'] as num).toInt() : _countWords(text);
      final punct = (e.payload['punctuationDensity'] is num)
          ? (e.payload['punctuationDensity'] as num).toDouble()
          : _punctDensity(text);
      final hasCaps = (e.payload['hasCaps'] ?? false) == true;
      final hasProf = (e.payload['hasProfanity'] ?? false) == true;

      _samples += 1;
      avgWords = _runningAvg(avgWords, _samples, words.toDouble());
      avgPunctDensity = _runningAvg(avgPunctDensity, _samples, punct);
      capsRate = _runningAvg(capsRate, _samples, hasCaps ? 1.0 : 0.0);
      profanityRate = _runningAvg(profanityRate, _samples, hasProf ? 1.0 : 0.0);

      for (final t in _tokenize(text)) {
        tokenCounts[t] = (tokenCounts[t] ?? 0) + 1;
      }
      // Persist asynchronously best-effort.
      persist();
    }
  }

  /// 0..100 with top 3 reasons. Offline.
  StyleFitResult styleFitScore(String draft) {
    final words = _countWords(draft);
    final punct = _punctDensity(draft);
    final hasCaps = _hasCaps(draft);
    final hasProf = _hasProfanity(draft);

    double score = 100.0;

    // Word count deviation.
    if (_samples >= 5) {
      final d = (words - avgWords).abs();
      if (d > 20) score -= 18;
      else if (d > 12) score -= 10;
      else if (d > 7) score -= 6;
    }

    // Punctuation deviation.
    if (_samples >= 5) {
      final d = (punct - avgPunctDensity).abs();
      if (d > 0.10) score -= 12;
      else if (d > 0.06) score -= 7;
    }

    // Caps/profanity are “style” features. Only penalize if mismatch is strong.
    if (_samples >= 8) {
      final capExpected = capsRate >= 0.4;
      if (hasCaps != capExpected) score -= 6;
      final profExpected = profanityRate >= 0.25;
      if (hasProf != profExpected) score -= 6;
    }

    if (score < 0) score = 0;

    final reasons = <String>[];
    if (_samples < 5) {
      reasons.add('Not enough history yet — this will get sharper as Twin+ learns.');
    } else {
      if (_samples >= 5) {
        if ((words - avgWords).abs() > 12) reasons.add('Length/cadence differs from your baseline.');
        if ((punct - avgPunctDensity).abs() > 0.06) reasons.add('Punctuation cadence differs from your baseline.');
      }
      if (_samples >= 8) {
        final capExpected = capsRate >= 0.4;
        if (hasCaps != capExpected) reasons.add('CAPS emphasis differs from your baseline.');
        final profExpected = profanityRate >= 0.25;
        if (hasProf != profExpected) reasons.add('Profanity intensity differs from your baseline.');
      }
    }

    // Lexicon overlap.
    final overlap = _lexiconOverlap(draft);
    if (_samples >= 10 && overlap < 0.08) {
      score -= 8;
      reasons.add('Vocabulary overlap is low compared to your usual phrasing.');
    }

    reasons.removeWhere((r) => r.trim().isEmpty);
    final top = reasons.take(3).toList(growable: false);

    return StyleFitResult(score: score.round(), reasons: top, words: words, punctuationDensity: punct);
  }

  double _lexiconOverlap(String draft) {
    if (tokenCounts.isEmpty) return 0.0;
    final topTokens = tokenCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final set = topTokens.take(80).map((e) => e.key).toSet();

    final toks = _tokenize(draft).toSet();
    if (toks.isEmpty) return 0.0;
    final inter = toks.where(set.contains).length;
    return inter / toks.length;
  }

  Map<String, dynamic> snapshot() => <String, dynamic>{
        'samples': _samples,
        'avgWords': avgWords,
        'avgPunctDensity': avgPunctDensity,
        'capsRate': capsRate,
        'profanityRate': profanityRate,
        'topTokens': (tokenCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(15)
            .map((e) => {'t': e.key, 'c': e.value})
            .toList(),
      };

  static double _runningAvg(double current, int n, double nextVal) {
    if (n <= 1) return nextVal;
    return current + ((nextVal - current) / n);
  }

  static double _asDouble(dynamic v) => (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;

  static Iterable<String> _tokenize(String text) sync* {
    final lower = text.toLowerCase();
    // NOTE: Use a double-quoted raw string so we can include a single-quote safely.
    // We want to keep contractions like "don't" as one token.
    final parts = lower.split(RegExp(r"[^a-z0-9']+"));
    for (final p in parts) {
      final t = p.trim();
      if (t.isEmpty) continue;
      if (t.length <= 2) continue;
      if (_stop.contains(t)) continue;
      yield t;
    }
  }

  static int _countWords(String s) => s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  static bool _hasCaps(String s) => RegExp(r'[A-Z]{2,}').hasMatch(s);

  static double _punctDensity(String s) {
    if (s.isEmpty) return 0.0;
    final punct = RegExp(r'[,\.\!\?\:\;\-\(\)\[\]\{\}"]').allMatches(s).length;
    return punct / s.length;
  }

  static bool _hasProfanity(String s) {
    final lower = s.toLowerCase();
    // Minimal list; Twin+ will learn personal boundaries via reinforcement, not static censorship.
    return lower.contains('fuck') || lower.contains('shit') || lower.contains('damn') || lower.contains('bastard');
  }

  static const Set<String> _stop = {
    'the','and','for','with','that','this','from','have','what','your','you','are','was','were','will','just','like','into',
    'then','than','them','they','their','there','here','when','where','why','how','can','could','should','would','a','an','to',
    'of','in','on','at','it','is','as','be','or','if','we','i','me','my','our','us'
  };
}

class StyleFitResult {
  final int score;
  final List<String> reasons;
  final int words;
  final double punctuationDensity;

  const StyleFitResult({
    required this.score,
    required this.reasons,
    required this.words,
    required this.punctuationDensity,
  });
}
