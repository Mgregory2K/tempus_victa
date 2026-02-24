import 'package:flutter/services.dart';

class UsageStatsIngestor {
  static const MethodChannel _ch = MethodChannel('tempus/ingest');

  static Future<bool> isUsageAccessEnabled() async {
    try {
      final v = await _ch.invokeMethod<bool>('isUsageAccessEnabled');
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openUsageAccessSettings() async {
    try {
      await _ch.invokeMethod('openUsageAccessSettings');
    } catch (_) {}
  }

  /// Returns a list of usage events since [sinceEpochMs] (inclusive) up to now (device time).
  /// Each event map contains: packageName, eventType, tsMs, className?
  static Future<List<Map<String, dynamic>>> fetchUsageEvents({required int sinceEpochMs, int maxEvents = 800}) async {
    try {
      final raw = await _ch.invokeMethod<List<dynamic>>('fetchUsageEvents', {
        'sinceEpochMs': sinceEpochMs,
        'maxEvents': maxEvents,
      });
      if (raw == null) return const [];
      return raw.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
