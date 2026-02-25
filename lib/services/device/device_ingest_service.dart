import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/notification_ingestor.dart';
import '../../core/signal_item.dart';
import '../../core/signal_store.dart';
import '../../core/twin_plus/twin_event.dart';
import '../../core/twin_plus/twin_plus_kernel.dart';
import '../../core/usage_ingestor.dart';

class DeviceIngestService {
  static final DeviceIngestService instance = DeviceIngestService._internal();
  DeviceIngestService._internal();

  static const _kLastUsageTs = 'tempus.device.lastUsageTsMs';

  Timer? _timer;
  bool _started = false;

  Future<void> init() async {
    if (_started) return;
    _started = true;

    // Prime last usage timestamp to "now - 10 min" so first run isn't huge.
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = prefs.getInt(_kLastUsageTs);
    if (existing == null || existing <= 0) {
      await prefs.setInt(_kLastUsageTs, now - 10 * 60 * 1000);
    }

    // Poll while app is running (dev-wide-open behavior).
    _timer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await _pullNotifications();
      await _pullUsage();
    });

    // Run once immediately.
    await _pullNotifications();
    await _pullUsage();
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  String _fingerprint(String pkg, String title, String body) => '$pkg|$title|$body';

  Future<void> _pullNotifications() async {
    final native = await NotificationIngestor.fetchAndClearSignals();
    if (native.isEmpty) return;

    final now = DateTime.now();
    final incoming = native.map((m) {
      final createdAt = DateTime.fromMillisecondsSinceEpoch(
        (m['createdAtMs'] is int) ? m['createdAtMs'] as int : (int.tryParse('${m['createdAtMs']}') ?? now.millisecondsSinceEpoch),
      );
      final pkg = (m['packageName'] ?? 'android').toString();
      final title = (m['title'] ?? '').toString().trim();
      final body = (m['body'] ?? '').toString().trim();
      final display = title.isNotEmpty ? title : (body.isNotEmpty ? body : 'Notification');
      final fp = _fingerprint(pkg, display, body);

      return SignalItem(
        id: (m['id'] ?? createdAt.microsecondsSinceEpoch.toString()).toString(),
        createdAt: createdAt,
        source: pkg,
        title: display,
        body: body.isEmpty ? null : body,
        fingerprint: fp,
        lastSeenAt: createdAt,
      );
    }).toList();

    // Merge + save.
    final existing = await SignalStore.load();
    final byFp = <String, SignalItem>{for (final s in existing) s.fingerprint: s};
    for (final s in incoming) {
      final e = byFp[s.fingerprint];
      if (e == null) {
        byFp[s.fingerprint] = s;
      } else {
        final newerLast = s.lastSeenAt.isAfter(e.lastSeenAt) ? s.lastSeenAt : e.lastSeenAt;
        byFp[s.fingerprint] = e.copyWith(lastSeenAt: newerLast, count: e.count + 1);
      }
    }
    final merged = byFp.values.toList()..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
    await SignalStore.save(merged.take(500).toList(growable: false));

    // Learn: one event per notification burst (not per notif).
    TwinPlusKernel.instance.observe(
      TwinEvent.actionPerformed(
        surface: 'device',
        action: 'notifications_ingested',
        entityType: 'signal',
        meta: {'count': incoming.length},
      ),
    );
  }

  Future<void> _pullUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_kLastUsageTs) ?? 0;
    if (last <= 0) return;

    final events = await UsageIngestor.fetchUsageEvents(sinceEpochMs: last, maxEvents: 200);
    if (events.isEmpty) return;

    // Advance watermark to last event ts.
    final maxTs = events
        .map((e) => (e['tsMs'] is int) ? e['tsMs'] as int : int.tryParse('${e['tsMs']}') ?? 0)
        .fold<int>(last, (a, b) => b > a ? b : a);
    await prefs.setInt(_kLastUsageTs, maxTs);

    // Learn: log each package switch as an actionPerformed (meta includes eventType).
    for (final e in events) {
      final pkg = (e['packageName'] ?? '').toString();
      if (pkg.isEmpty) continue;
      TwinPlusKernel.instance.observe(
        TwinEvent.actionPerformed(
          surface: 'device',
          action: 'usage_event',
          entityType: 'app',
          entityId: pkg,
          meta: {
            'eventType': e['eventType'],
            'tsMs': e['tsMs'],
            'className': e['className'],
          },
          confidence: 0.2, // low weight per your tenth-decimal doctrine (aggregates later)
        ),
      );
    }
  }
}
