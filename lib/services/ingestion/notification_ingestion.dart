import 'package:flutter/services.dart';

class NotificationIngestion {
  static const MethodChannel _ch = MethodChannel('tempus/ingestion');

  static Future<bool> isEnabled() async {
    try {
      final v = await _ch.invokeMethod<bool>('is_notification_listener_enabled');
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openSettings() async {
    try {
      await _ch.invokeMethod('open_notification_listener_settings');
    } catch (_) {
      // ignore
    }
  }
}
