import 'package:shared_preferences/shared_preferences.dart';

class AiSettings {
  static const _kEnabled = 'ai_enabled';
  static const _kModel = 'ai_model';
  static const _kApiKey = 'ai_api_key';
  static const _kEndpoint = 'ai_endpoint';

  static Future<bool> getEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, enabled);
  }

  static Future<String?> getModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kModel);
  }

  static Future<void> setModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModel, model);
  }

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kApiKey);
  }

  static Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiKey, key);
  }

  static Future<String?> getEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kEndpoint);
  }

  static Future<void> setEndpoint(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEndpoint, endpoint);
  }

  // --- Usage caps (soft guardrails) ---
  // NOTE: Single-user app; caps exist to avoid accidental runaway costs.
  static const _kMonthlyCapTokens = 'ai_monthly_cap_tokens';
  static const _kUsedMonthlyTokens = 'ai_used_monthly_tokens';
  static const _kUsedMonthKey = 'ai_used_month_key'; // YYYY-MM

  static String _monthKey(DateTime utcNow) => '${utcNow.year.toString().padLeft(4,'0')}-${utcNow.month.toString().padLeft(2,'0')}';

  static Future<int> getMonthlyCapTokens() async {
    final prefs = await SharedPreferences.getInstance();
    // default: no cap (0 means unlimited)
    return prefs.getInt(_kMonthlyCapTokens) ?? 0;
  }

  static Future<void> setMonthlyCapTokens(int tokens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kMonthlyCapTokens, tokens);
  }

  static Future<int> getUsedMonthlyTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final nowKey = _monthKey(DateTime.now().toUtc());
    final storedKey = prefs.getString(_kUsedMonthKey);
    if (storedKey != nowKey) {
      // new month -> reset
      await prefs.setString(_kUsedMonthKey, nowKey);
      await prefs.setInt(_kUsedMonthlyTokens, 0);
      return 0;
    }
    return prefs.getInt(_kUsedMonthlyTokens) ?? 0;
  }

  static Future<void> addUsedTokens(int used) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getUsedMonthlyTokens();
    await prefs.setInt(_kUsedMonthlyTokens, current + used);
  }

  static Future<bool> underCapOrDisabled({required int plannedTokens}) async {
    final enabled = await getEnabled();
    if (!enabled) return true;

    final cap = await getMonthlyCapTokens();
    if (cap <= 0) return true; // unlimited

    final used = await getUsedMonthlyTokens();
    return (used + plannedTokens) <= cap;
  }

}
