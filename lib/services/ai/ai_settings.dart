// Tempus Vista rebuild - generated 2026-02-21
// Local-first, Android-first.


import '../../data/db/app_db.dart';

class AiSettings {
  static const _kEnabled = 'ai:enabled';
  static const _kMonthlyCapTokens = 'ai:cap_monthly_tokens';
  static const _kUsedMonthlyTokens = 'ai:used_monthly_tokens';

  static Future<bool> isEnabled() async {
    final v = (await AppDb.instance.getMeta(_kEnabled))?.trim().toLowerCase();
    return v == null ? true : (v == 'true' || v == '1' || v == 'yes');
  }

  static Future<void> setEnabled(bool enabled) => AppDb.instance.setMeta(_kEnabled, enabled ? 'true' : 'false');

  static Future<int> getMonthlyCapTokens() async {
    final v = int.tryParse((await AppDb.instance.getMeta(_kMonthlyCapTokens)) ?? '') ?? 200000;
    return v;
  }

  static Future<void> setMonthlyCapTokens(int tokens) => AppDb.instance.setMeta(_kMonthlyCapTokens, tokens.toString());

  static Future<int> getUsedMonthlyTokens() async {
    final v = int.tryParse((await AppDb.instance.getMeta(_kUsedMonthlyTokens)) ?? '') ?? 0;
    return v;
  }

  static Future<void> addUsedTokens(int used) async {
    final current = await getUsedMonthlyTokens();
    await AppDb.instance.setMeta(_kUsedMonthlyTokens, (current + used).toString());
  }

  static Future<bool> underCapOrDisabled({required int plannedTokens}) async {
    if (!await isEnabled()) return true;
    final cap = await getMonthlyCapTokens();
    final used = await getUsedMonthlyTokens();
    return (used + plannedTokens) <= cap;
  }
}
