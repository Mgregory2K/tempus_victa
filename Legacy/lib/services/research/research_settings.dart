import '../../providers/db_provider.dart';

class ResearchSettings {
  static const _kWebEnabled = 'research.web_enabled';

  /// Internet ON by default (free).
  static Future<bool> getWebEnabled() async {
    final v = (await DbProvider.db.getMeta(_kWebEnabled))?.trim().toLowerCase();
    if (v == null || v.isEmpty) return true;
    return v == 'true' || v == '1' || v == 'yes' || v == 'on';
  }

  static Future<void> setWebEnabled(bool enabled) =>
      DbProvider.db.setMeta(_kWebEnabled, enabled ? 'true' : 'false');
}
