import 'package:flutter/services.dart';

class NotificationIngestor {
  static const MethodChannel _ch = MethodChannel('tempus/ingest');

  static Future<bool> isNotificationAccessEnabled() async {
    try {
      final v = await _ch.invokeMethod<bool>('isNotificationAccessEnabled');
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<int> getNativeBufferSize() async {
    try {
      final v = await _ch.invokeMethod<int>('getNativeBufferSize');
      return v ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> openNotificationAccessSettings() async {
    try {
      await _ch.invokeMethod('openNotificationAccessSettings');
    } catch (_) {}
  }

  static Future<void> openAppNotificationSettings() async {
    try {
      await _ch.invokeMethod('openAppNotificationSettings');
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> fetchAndClearSignals() async {
    try {
      final raw = await _ch.invokeMethod<List<dynamic>>('fetchAndClearSignals');
      if (raw == null) return const [];
      return raw.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
