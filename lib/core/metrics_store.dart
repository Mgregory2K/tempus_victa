import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight, local-first metrics for the user.
///
/// Goals:
/// - Always-on (no AI required)
/// - Private (stored only on device)
/// - Cheap (SharedPreferences)
///
/// This is intentionally simple for Phase 1.
class MetricsStore {
  static const _kPrefixToday = 'tv.metrics.today.'; // date-scoped
  static const _kPrefixTotal = 'tv.metrics.total.'; // lifetime

  static String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static Future<void> inc(String metric, [int by = 1]) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final kToday = '$_kPrefixToday$today.$metric';
    final kTotal = '$_kPrefixTotal$metric';
    prefs.setInt(kToday, (prefs.getInt(kToday) ?? 0) + by);
    prefs.setInt(kTotal, (prefs.getInt(kTotal) ?? 0) + by);
  }

  static Future<int> getToday(String metric) async {
    final prefs = await SharedPreferences.getInstance();
    final k = '$_kPrefixToday${_todayKey()}.$metric';
    return prefs.getInt(k) ?? 0;
  }

  static Future<int> getTotal(String metric) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_kPrefixTotal$metric') ?? 0;
  }

  static Future<Map<String, int>> todaySnapshot(List<String> metrics) async {
    final prefs = await SharedPreferences.getInstance();
    final base = '$_kPrefixToday${_todayKey()}.';
    return {
      for (final m in metrics) m: prefs.getInt('$base$m') ?? 0,
    };
  }
}

/// Canonical metric names used across the app.
class TvMetrics {
  static const signalsIngested = 'signals_ingested';
  static const signalsPromotedToTask = 'signals_to_task';
  static const signalsRecycled = 'signals_recycled';

  static const tasksCreatedManual = 'tasks_created_manual';
  static const tasksCreatedVoice = 'tasks_created_voice';

  static const webSearches = 'web_searches';
  static const aiCalls = 'ai_calls';
}
