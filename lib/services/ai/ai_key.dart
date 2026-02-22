// Tempus Vista rebuild - generated 2026-02-21
// Local-first, Android-first.


import '../../data/db/app_db.dart';

class AiKey {
  static const _kApiKey = 'openai:api_key';

  static Future<String?> get() => AppDb.instance.getMeta(_kApiKey);

  static Future<void> set(String key) => AppDb.instance.setMeta(_kApiKey, key);

  static Future<void> clear() => AppDb.instance.deleteMeta(_kApiKey);
}
