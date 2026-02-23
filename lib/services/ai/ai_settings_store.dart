import 'package:shared_preferences/shared_preferences.dart';

class AiSettings {
  final bool enabled;
  final String? apiKey;
  final String? model;

  const AiSettings({required this.enabled, required this.apiKey, required this.model});
}

/// Local-first AI configuration. AI is opt-in and must never block baseline app behavior.
class AiSettingsStore {
  static const _kEnabled = 'tempus.ai.enabled.v1';
  static const _kApiKey = 'tempus.ai.openai_api_key.v1';
  static const _kModel = 'tempus.ai.model.v1';

  static Future<AiSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kEnabled) ?? false;
    final apiKeyRaw = prefs.getString(_kApiKey);
    final apiKey = (apiKeyRaw == null || apiKeyRaw.trim().isEmpty) ? null : apiKeyRaw.trim();
    final modelRaw = prefs.getString(_kModel);
    final model = (modelRaw == null || modelRaw.trim().isEmpty) ? null : modelRaw.trim();
    return AiSettings(enabled: enabled, apiKey: apiKey, model: model);
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? false;
  }

  static Future<void> setEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, v);
  }

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_kApiKey);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  static Future<void> setApiKey(String v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiKey, v.trim());
  }

  static Future<String> getModel() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_kModel);
    // Keep a conservative default that is widely available.
    return (v == null || v.trim().isEmpty) ? 'gpt-4o-mini' : v.trim();
  }

  static Future<void> setModel(String v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModel, v.trim());
  }
}
