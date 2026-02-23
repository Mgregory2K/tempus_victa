import 'package:shared_preferences/shared_preferences.dart';

/// Metric keys used across Tempus, Victa.
/// Keep these as const Strings so they can be used in const lists and maps.
class TvMetrics {
  static const String signalsIngested = 'signalsIngested';
  static const String signalsAcknowledged = 'signalsAcknowledged';
  static const String tasksCreatedManual = 'tasksCreatedManual';
  static const String tasksCreatedVoice = 'tasksCreatedVoice';
  static const String webSearches = 'webSearches';
  static const String aiCalls = 'aiCalls';
  static const String projectsOpened = 'projectsOpened';
  static const String corkboardCreated = 'corkboardCreated';
}

/// Back-compat alias used by some rooms.
class MetricKeys {
  static const String signalsIngested = TvMetrics.signalsIngested;
  static const String signalsAcknowledged = TvMetrics.signalsAcknowledged;
  static const String tasksCreatedManual = TvMetrics.tasksCreatedManual;
  static const String tasksCreatedVoice = TvMetrics.tasksCreatedVoice;
  static const String webSearches = TvMetrics.webSearches;
  static const String aiReplies = TvMetrics.aiCalls;
  static const String aiCalls = TvMetrics.aiCalls;
  static const String projectsOpened = TvMetrics.projectsOpened;
}

class MetricsSnapshot {
  final DateTime day; // local day
  final Map<String, int> metrics;
  const MetricsSnapshot({required this.day, required this.metrics});
}

class MetricsStore {
  static String _dayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  static Future<void> bump(String key, [int by = 1]) async {
    final prefs = await SharedPreferences.getInstance();
    final day = _dayKey(DateTime.now());
    final k = 'tv.metrics.$day.$key';
    final current = prefs.getInt(k) ?? 0;
    await prefs.setInt(k, current + by);
  }

  /// Back-compat alias used by older code.
  static Future<void> inc(String key, [int by = 1]) => bump(key, by);

  /// Loads a map of requested metrics for today.
  static Future<Map<String, int>> load([List<String>? keys]) async {
    final prefs = await SharedPreferences.getInstance();
    final day = _dayKey(DateTime.now());
    final want = keys ??
        const [
          TvMetrics.signalsIngested,
          TvMetrics.signalsAcknowledged,
          TvMetrics.tasksCreatedManual,
          TvMetrics.tasksCreatedVoice,
          TvMetrics.webSearches,
          TvMetrics.aiCalls,
          TvMetrics.projectsOpened,
        ];

    final out = <String, int>{};
    for (final k in want) {
      out[k] = prefs.getInt('tv.metrics.$day.$k') ?? 0;
    }
    return out;
  }

  /// More structured snapshot (used by Daily Brief).
  static Future<MetricsSnapshot> todaySnapshot(List<String> keys) async {
    final m = await load(keys);
    return MetricsSnapshot(day: DateTime.now(), metrics: m);
  }
}
