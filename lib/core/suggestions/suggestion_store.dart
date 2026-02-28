import 'package:shared_preferences/shared_preferences.dart';

import '../app_settings_store.dart';

/// Controls whether suggestion UI can show (throttle, dismiss, strictness).
class SuggestionStore {
  static const String _kDismissUntil = 'suggestions.dismiss_until';
  static const String _kLastShownAt = 'suggestions.last_shown_at';

  /// If dismissed, returns true.
  Future<bool> isDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    final untilMs = prefs.getInt(_kDismissUntil) ?? 0;
    if (untilMs <= 0) return false;
    return DateTime.now().millisecondsSinceEpoch < untilMs;
  }

  Future<void> dismissForHours(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    final until = DateTime.now().add(Duration(hours: hours)).millisecondsSinceEpoch;
    await prefs.setInt(_kDismissUntil, until);
  }

  Future<bool> canShowNow() async {
    final assistantEnabled = await AppSettingsStore().loadAssistantEnabled();
    if (!assistantEnabled) return false;

    if (await isDismissed()) return false;

    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_kLastShownAt) ?? 0;
    if (lastMs <= 0) return true;

    // Simple cooldown: 2 minutes between banners.
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    return DateTime.now().difference(last).inSeconds >= 120;
  }

  Future<void> markShownNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastShownAt, DateTime.now().millisecondsSinceEpoch);
  }

  /// Selects a suggestion using strictness threshold.
  /// Returns null if below threshold.
  Future<T?> selectBest<T>({
    required List<T> candidates,
    required String Function(T) idOf,
    required double Function(T) confidenceOf,
  }) async {
    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => confidenceOf(b).compareTo(confidenceOf(a)));
    final best = candidates.first;

    final strict = await AppSettingsStore().loadSuggestionStrictness();
    final minConf = strict == 2 ? 0.82 : (strict == 0 ? 0.52 : 0.65);
    if (confidenceOf(best) < minConf) return null;

    return best;
  }
}
