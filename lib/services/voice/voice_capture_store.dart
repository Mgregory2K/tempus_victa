import 'voice_service.dart';

class VoiceCaptureStore {
  static final Map<String, _Entry> _latestByKey = {};

  static String _k(String surface, String fieldId) => '$surface::$fieldId';

  static void set({
    required String surface,
    required String fieldId,
    required VoiceResult result,
  }) {
    _latestByKey[_k(surface, fieldId)] = _Entry(result: result, tsMs: DateTime.now().millisecondsSinceEpoch);
  }

  /// Consume the latest capture for this surface/field if it looks like it matches the provided text.
  /// This is intentionally conservative to avoid mis-attaching voice metadata to typed tasks.
  static VoiceResult? consumeIfMatch({
    required String surface,
    required String fieldId,
    required String text,
    int maxAgeMs = 30000,
  }) {
    final key = _k(surface, fieldId);
    final e = _latestByKey[key];
    if (e == null) return null;

    final age = DateTime.now().millisecondsSinceEpoch - e.tsMs;
    if (age > maxAgeMs) {
      _latestByKey.remove(key);
      return null;
    }

    final t = text.trim();
    final r = e.result.transcript.trim();
    if (t.isEmpty || r.isEmpty) {
      _latestByKey.remove(key);
      return null;
    }

    // Exact match is best. Fallback: startsWith (speech partials sometimes omit trailing punctuation).
    final ok = (t == r) || (r.startsWith(t)) || (t.startsWith(r));
    if (!ok) return null;

    _latestByKey.remove(key);
    return e.result;
  }
}

class _Entry {
  final VoiceResult result;
  final int tsMs;
  const _Entry({required this.result, required this.tsMs});
}
