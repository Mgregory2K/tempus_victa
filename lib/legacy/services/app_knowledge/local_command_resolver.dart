import 'app_capabilities.dart';

class LocalCommandResult {
  final String title;
  final String body;
  final String actionUrl; // e.g. app://nav?tab=2

  const LocalCommandResult({
    required this.title,
    required this.body,
    required this.actionUrl,
  });
}

class LocalCommandResolver {
  /// Returns a nav/action result if the user intent looks like a local command.
  /// Otherwise returns null and routing continues.
  static LocalCommandResult? tryResolve(String rawQuery) {
    final q = _normalize(rawQuery);
    if (q.isEmpty) return null;

    // Navigation verbs
    final wantsNav = _containsAny(q, const [
      'open',
      'go to',
      'goto',
      'show',
      'take me to',
      'navigate',
      'bring up',
    ]);

    // If not a nav-ish command, don’t hijack.
    if (!wantsNav) return null;

    // Find best matching capability by keywords/title
    final match = _bestCapabilityMatch(q);
    if (match == null) return null;

    final cap = match;

    // If capability has a tabIndex, return internal nav action.
    if (cap.tabIndex != null) {
      return LocalCommandResult(
        title: 'Navigate',
        body: 'Opening ${cap.title}.',
        actionUrl: 'app://nav?tab=${cap.tabIndex}',
      );
    }

    // No tab index known: still helpful
    return LocalCommandResult(
      title: 'Navigate',
      body: '${cap.title} is available. Where: ${cap.where}',
      actionUrl: 'app://help?id=${cap.id}',
    );
  }

  static AppCapability? _bestCapabilityMatch(String q) {
    AppCapability? best;
    double bestScore = 0;

    for (final cap in AppCapabilities.all) {
      final hay = _normalize([
        cap.title,
        cap.id,
        cap.where,
        cap.summary,
        ...cap.keywords,
      ].join(' '));

      double score = 0;

      // direct contains
      if (hay.contains(q)) score += 3;

      // token overlap
      final qt = _tokens(q);
      final ht = _tokens(hay);
      score += qt.where(ht.contains).length.toDouble();

      // keyword boost
      for (final kw in cap.keywords) {
        final nkw = _normalize(kw);
        if (nkw.isNotEmpty && q.contains(nkw)) score += 1.25;
      }

      if (score > bestScore) {
        bestScore = score;
        best = cap;
      }
    }

    // gate
    if (bestScore < 2) return null;
    return best;
  }

  static bool _containsAny(String q, List<String> needles) {
    for (final n in needles) {
      if (q.contains(n)) return true;
    }
    return false;
  }

  static String _normalize(String s) {
    var x = s.toLowerCase().trim();
    x = x.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    x = x.replaceAll(RegExp(r'\s+'), ' ').trim();
    return x;
  }

  static Set<String> _tokens(String s) =>
      s.split(' ').where((p) => p.length >= 2).toSet();
}
