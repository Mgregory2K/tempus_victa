import '../notif_ingest.dart';
import '../telemetry/behavior_telemetry.dart';
import '../settings/ingestion_settings.dart';

/// Starts/stops ingestion sources based on sticky opt-in settings.
/// This is intentionally conservative: if master is OFF, nothing runs.
class IngestionDispatcher {
  IngestionDispatcher._();

  static final IngestionDispatcher I = IngestionDispatcher._();

  final NotifIngest _notif = NotifIngest();

  bool _running = false;

  Future<void> applyCurrentSettings() async {
    final master = await IngestionSettings.getMasterEnabled();
    if (!master) {
      await stopAll();
      return;
    }

    // Master ON: selectively enable sources.
    // Notifications is the most universal signal pipe; still requires the Android
    // Notification Listener service being enabled in system settings.
    final notif = await IngestionSettings.getNotificationsEnabled();
    if (notif) {
      await _notif.start();
      BehaviorTelemetry.log('ingest.notif.start', {});
    } else {
      await _notif.stop();
      BehaviorTelemetry.log('ingest.notif.stop', {});
    }

    // SMS / Calls / Calendar / Contacts:
    // These are intentionally stubbed here until their platform-specific wiring
    // is added. The toggles + permissions are real; wiring comes next.
    final sms = await IngestionSettings.getSmsEnabled();
    final calls = await IngestionSettings.getCallsEnabled();
    final cal = await IngestionSettings.getCalendarEnabled();
    final contacts = await IngestionSettings.getContactsEnabled();

    BehaviorTelemetry.log('ingest.apply', {
      'master': master,
      'notifications': notif,
      'sms': sms,
      'calls': calls,
      'calendar': cal,
      'contacts': contacts,
    });

    _running = true;
  }

  Future<void> stopAll() async {
    await _notif.stop();
    if (_running) {
      BehaviorTelemetry.log('ingest.stop_all', {});
    }
    _running = false;
  }
}
