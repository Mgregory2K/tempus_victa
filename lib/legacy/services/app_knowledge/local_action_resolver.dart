import '../../data/repos/actions_repo.dart';
import '../research/intelligence_router.dart';

class LocalActionResolver {
  static final ActionsRepo _repo = ActionsRepo();

  /// Returns RouterItems if input is an "add action" intent. Otherwise null.
  static Future<List<RouterItem>?> tryCreateAction(String rawQuery) async {
    final q = rawQuery.trim();
    if (q.isEmpty) return null;

    final normalized = _normalize(q);

    // Intent patterns (tight + deterministic)
    final title = _extractActionTitle(normalized, original: q);
    if (title == null) return null;

    final created = await _repo.add(title: title);

    return [
      RouterItem(
        stage: RouteStage.local,
        title: 'Action created',
        body: '“${created.title}”',
      ),
      RouterItem(
        stage: RouteStage.local,
        title: 'Navigate',
        body: 'Open Actions to view it.',
        url: 'app://nav?tab=5&id=actions&q=${Uri.encodeComponent(rawQuery)}',
      ),
    ];
  }

  static String? _extractActionTitle(String normalized, {required String original}) {
    // Patterns:
    // "add action: X"
    // "add action X"
    // "todo X"
    // "task X"
    // "remind me to X"
    // "reminder: X"

    // Colon variant
    final colonMatch = RegExp(
      r'^(add action|action|todo|task|reminder)\s*:\s*(.+)$',
    ).firstMatch(normalized);
    if (colonMatch != null) {
      final t = (colonMatch.group(2) ?? '').trim();
      return t.isEmpty ? null : t;
    }

    // "remind me to ..."
    final remindMatch = RegExp(r'^remind me to\s+(.+)$').firstMatch(normalized);
    if (remindMatch != null) {
      final t = (remindMatch.group(1) ?? '').trim();
      return t.isEmpty ? null : t;
    }

    // Space variant: "add action X" / "todo X" / "task X"
    final spaceMatch = RegExp(r'^(add action|todo|task)\s+(.+)$').firstMatch(normalized);
    if (spaceMatch != null) {
      final t = (spaceMatch.group(2) ?? '').trim();
      return t.isEmpty ? null : t;
    }

    return null;
  }

  static String _normalize(String s) {
    var x = s.toLowerCase().trim();
    x = x.replaceAll(RegExp(r'[^a-z0-9\s:]'), ' ');
    x = x.replaceAll(RegExp(r'\s+'), ' ').trim();
    return x;
  }
}
