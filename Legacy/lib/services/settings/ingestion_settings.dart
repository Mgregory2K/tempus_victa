import '../../providers/db_provider.dart';

/// Sticky, local-first ingestion gates.
/// Default OFF until the user explicitly opts in.
class IngestionSettings {
  // Master switch
  static const _kMasterEnabled = 'ingest.enabled';

  // Per-source toggles
  static const _kNotifEnabled = 'ingest.notifications_enabled';
  static const _kSmsEnabled = 'ingest.sms_enabled';
  static const _kCallsEnabled = 'ingest.calls_enabled';
  static const _kCalendarEnabled = 'ingest.calendar_enabled';
  static const _kContactsEnabled = 'ingest.contacts_enabled';

  static Future<bool> getMasterEnabled() async {
    final v = await DbProvider.db.getMeta(_kMasterEnabled);
    return v == '1';
  }

  static Future<void> setMasterEnabled(bool enabled) async {
    await DbProvider.db.setMeta(_kMasterEnabled, enabled ? '1' : '0');
  }

  static Future<bool> getNotificationsEnabled() async {
    final v = await DbProvider.db.getMeta(_kNotifEnabled);
    return v == '1';
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    await DbProvider.db.setMeta(_kNotifEnabled, enabled ? '1' : '0');
  }

  static Future<bool> getSmsEnabled() async {
    final v = await DbProvider.db.getMeta(_kSmsEnabled);
    return v == '1';
  }

  static Future<void> setSmsEnabled(bool enabled) async {
    await DbProvider.db.setMeta(_kSmsEnabled, enabled ? '1' : '0');
  }

  static Future<bool> getCallsEnabled() async {
    final v = await DbProvider.db.getMeta(_kCallsEnabled);
    return v == '1';
  }

  static Future<void> setCallsEnabled(bool enabled) async {
    await DbProvider.db.setMeta(_kCallsEnabled, enabled ? '1' : '0');
  }

  static Future<bool> getCalendarEnabled() async {
    final v = await DbProvider.db.getMeta(_kCalendarEnabled);
    return v == '1';
  }

  static Future<void> setCalendarEnabled(bool enabled) async {
    await DbProvider.db.setMeta(_kCalendarEnabled, enabled ? '1' : '0');
  }

  static Future<bool> getContactsEnabled() async {
    final v = await DbProvider.db.getMeta(_kContactsEnabled);
    return v == '1';
  }

  static Future<void> setContactsEnabled(bool enabled) async {
    await DbProvider.db.setMeta(_kContactsEnabled, enabled ? '1' : '0');
  }
}
