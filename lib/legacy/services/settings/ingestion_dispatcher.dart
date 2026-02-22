import '../settings/ingestion_settings.dart';

// NOTE: This dispatcher is intentionally conservative.
// It only starts/stops sources that already exist in your codebase.
// For now: notifications start/stop is handled via NotifIngest if present.
// SMS/Calls/Calendar/Contacts remain gated until their ingest services are added.

import '../ingest/notif_ingest.dart';

class IngestionDispatcher {
  static bool _notifRunning = false;

  static Future<void> applyFromSettings() async {
    final s = await IngestionSettings.read();

    if (!s.masterEnabled) {
      await stopAll();
      return;
    }

    // Notifications
    if (s.notificationsEnabled) {
      await _startNotif();
    } else {
      await _stopNotif();
    }

    // TODO: wire SMS / Calls / Calendar / Contacts when ingest services exist.
  }

  static Future<void> stopAll() async {
    await _stopNotif();
    // TODO stop other ingest sources when added.
  }

  static Future<void> _startNotif() async {
    if (_notifRunning) return;
    _notifRunning = true;
    try {
      await NotifIngest.start();
    } catch (_) {
      // Swallow: UI will surface errors later with human-readable messaging.
    }
  }

  static Future<void> _stopNotif() async {
    if (!_notifRunning) return;
    _notifRunning = false;
    try {
      await NotifIngest.stop();
    } catch (_) {}
  }
}
