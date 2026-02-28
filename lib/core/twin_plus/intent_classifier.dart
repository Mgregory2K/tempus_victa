/// Lightweight, deterministic intent classifier.
///
/// This is intentionally heuristic (no ML) so it is:
/// - fast
/// - transparent
/// - stable across offline mode
library;

class IntentSignalsLite {
  final bool timeSensitive;
  final bool needsVerifiableFacts;
  final bool followUp;

  const IntentSignalsLite({
    required this.timeSensitive,
    required this.needsVerifiableFacts,
    required this.followUp,
  });
}

class IntentClassifier {
  static IntentSignalsLite classify({required String queryText, List<String> recentUserTurns = const <String>[]}) {
    final q = queryText.trim().toLowerCase();

    // Time-sensitive / freshness cues.
    const timeWords = <String>[
      'today',
      'tonight',
      'tomorrow',
      'yesterday',
      'this week',
      'this month',
      'this year',
      'right now',
      'current',
      'latest',
      'most recent',
      'as of',
      'breaking',
      'news',
      'recent',
      'newest',
      'update',
      'updated',
      'release',
      'patch',
      'version',
      'price',
      'pricing',
      'stock',
      'schedule',
      'score',
      'weather',
    ];
    final timeSensitive = timeWords.any((w) => q.contains(w));

    // Verifiable fact cues.
    const verifyWords = <String>[
      'source',
      'citation',
      'link',
      'proof',
      'verify',
      'confirmed',
      'official',
      'documentation',
      'docs',
      'policy',
      'law',
      'regulation',
      'standard',
      'cve',
      'advisory',
    ];
    final needsVerifiableFacts = timeSensitive || verifyWords.any((w) => q.contains(w));

    // Follow-up (simple): short question + context.
    final isShort = q.length < 45;
    final hasContext = recentUserTurns.isNotEmpty;
    final followUpCues = <String>['that', 'this', 'it', 'them', 'also', 'and', 'so', 'then', 'what about', 'how about', 'why'];
    final hasCue = followUpCues.any((c) => q == c || q.startsWith('$c ') || q.contains(' $c '));
    final followUp = hasContext && (hasCue || (isShort && q.endsWith('?')));

    return IntentSignalsLite(
      timeSensitive: timeSensitive,
      needsVerifiableFacts: needsVerifiableFacts,
      followUp: followUp,
    );
  }
}
