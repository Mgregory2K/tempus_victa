import 'app_capabilities.dart';

class AppKnowledgeMatch {
  final AppCapability cap;
  final double score;

  const AppKnowledgeMatch(this.cap, this.score);
}

class AppKnowledge {
  static const double _minScore = 2.0;

  /// Returns a local-first help answer if the query looks like it’s about the app,
  /// otherwise returns null so normal routing continues.
  static String? tryAnswer(String rawQuery) {
    final q = _normalize(rawQuery);
    if (q.isEmpty) return null;

    // Fast gate: if it doesn't look like app/self-help, don't hijack normal queries.
    if (!_looksLikeAppQuestion(q)) return null;

    final matches = _searchCapabilities(q);
    if (matches.isEmpty) return _genericHelpFallback();

    final top = matches.first;
    if (top.score < _minScore) return _genericHelpFallback();

    // Return a compact, deterministic answer.
    final cap = top.cap;
    final b = StringBuffer();
    b.writeln('${cap.title}');
    b.writeln('${cap.summary}');
    b.writeln('');
    b.writeln('Where: ${cap.where}');
    if (cap.howTo.isNotEmpty) {
      b.writeln('');
      b.writeln('How:');
      for (final line in cap.howTo.take(3)) {
        b.writeln('• $line');
      }
    }

    // If there are other close matches, offer them as “Related”
    final related = matches.skip(1).take(2).map((m) => m.cap.title).toList();
    if (related.isNotEmpty) {
      b.writeln('');
      b.writeln('Related: ${related.join(', ')}');
    }

    return b.toString().trim();
  }

  static String _genericHelpFallback() {
    return [
      'App Help',
      'I can help with questions about Tempus Victa modules and where things live.',
      '',
      'Try asking:',
      '• "Where is Corkboard?"',
      '• "How do I enable AI?"',
      '• "Where do I put my API key?"',
      '• "What is Signal Bay?"',
    ].join('\n');
  }

  static List<AppKnowledgeMatch> _searchCapabilities(String normalizedQuery) {
    final qTokens = _tokens(normalizedQuery);
    final out = <AppKnowledgeMatch>[];

    for (final cap in AppCapabilities.all) {
      final text = _normalize([
        cap.title,
        cap.summary,
        cap.where,
        ...cap.howTo,
        ...cap.keywords,
      ].join(' '));

      double score = 0.0;

      // Token overlap
      final tTokens = _tokens(text);
      final overlap = qTokens.where(tTokens.contains).length;
      score += overlap.toDouble();

      // Phrase contains boosts
      if (text.contains(normalizedQuery)) score += 2.0;

      // Keyword contains boosts
      for (final kw in cap.keywords) {
        final nkw = _normalize(kw);
        if (nkw.isEmpty) continue;
        if (normalizedQuery.contains(nkw) || text.contains(nkw)) {
          score += 0.5;
        }
      }

      if (score > 0) out.add(AppKnowledgeMatch(cap, score));
    }

    out.sort((a, b) => b.score.compareTo(a.score));
    return out;
  }

  static bool _looksLikeAppQuestion(String q) {
    // Self-help / navigation intent indicators
    const starters = [
      'what is',
      'where is',
      'where are',
      'how do i',
      'how to',
      'help',
      'settings',
      'api key',
      'openai key',
      'key',
      'token',
      'enable',
      'turn on',
      'turn off',
      'toggle',
    ];

    // Direct mention of known module names
    const modules = [
      'ready room',
      'signal bay',
      'signals',
      'corkboard',
      'quote board',
      'quotes',
      'actions',
      'tasks',
      'settings',
      'tempus',
      'tempus victa',
    ];

    for (final s in starters) {
      if (q.startsWith(s)) return true;
      if (q.contains(s)) return true;
    }
    for (final m in modules) {
      if (q.contains(m)) return true;
    }
    return false;
  }

  static String _normalize(String s) {
    var x = s.toLowerCase().trim();
    // Remove punctuation-ish characters but keep spaces.
    x = x.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    // Collapse whitespace
    x = x.replaceAll(RegExp(r'\s+'), ' ').trim();
    return x;
  }

  static Set<String> _tokens(String s) {
    final parts = s.split(' ');
    return parts.where((p) => p.length >= 2).toSet();
  }
}
