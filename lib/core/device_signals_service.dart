import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_ingestor.dart';
import 'signal_item.dart';
import 'signal_store.dart';
import 'twin_plus/twin_event.dart';
import 'twin_plus/twin_plus_kernel.dart';
import 'usage_stats_ingestor.dart';

class DeviceSignalsService with WidgetsBindingObserver {
  static final DeviceSignalsService instance = DeviceSignalsService._();
  DeviceSignalsService._();

  static const _kLastUsageFetchMs = 'tempus.deviceSignals.lastUsageFetchMs.v1';
  static const _kEnabled = 'tempus.deviceSignals.enabled.v1';

  TwinPlusKernel? _kernel;
  Timer? _timer;
  bool _running = false;

  /// Global opt-in gate for device-wide ingestion.
  /// Default: false (must be explicitly turned on).
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? false;
  }

  Future<void> setEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, v);
    if (!v) {
      await stop();
    } else {
      // If caller already started, resume polling immediately.
      if (_kernel != null) {
        await start(kernel: _kernel!);
      }
    }
  }

  Future<void> start({required TwinPlusKernel kernel}) async {
    _kernel = kernel;
    if (_running) return;

    // Respect opt-in
    if (!await isEnabled()) return;

    _running = true;
    WidgetsBinding.instance.addObserver(this);

    // Prime fetch windows
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt(_kLastUsageFetchMs, prefs.getInt(_kLastUsageFetchMs) ?? DateTime.now().millisecondsSinceEpoch - 5 * 60 * 1000);

    // Poll while app is foregrounded
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
    // Immediate tick
    unawaited(_tick());
  }

  Future<void> stop() async {
    _running = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_tick());
    }
  }

  Future<void> _tick() async {
    final kernel = _kernel;
    if (!_running || kernel == null) return;
    if (!await isEnabled()) return;

    await _ingestNotifications(kernel);
    await _ingestUsage(kernel);
  }

  Future<void> _ingestNotifications(TwinPlusKernel kernel) async {
    final enabled = await NotificationIngestor.isNotificationAccessEnabled();
    if (!enabled) return;

    final rows = await NotificationIngestor.fetchAndClearSignals();
    if (rows.isEmpty) return;

    // Convert to SignalItems with dedupe
    final now = DateTime.now();
    final existing = await SignalStore.load();
    final byFp = {for (final s in existing) s.fingerprint: s};

    for (final r in rows) {
      final pkg = (r['packageName'] ?? 'android').toString();
      final title = (r['title'] ?? '').toString().trim();
      final body = (r['body'] ?? '').toString().trim();
      final fp = body.isEmpty
          ? '$pkg|$title|${(r['createdAtMs'] ?? now.millisecondsSinceEpoch)}'
          : '$pkg|$title|$body';

      final prev = byFp[fp];
      if (prev == null) {
        final item = SignalItem(
          id: (r['id'] ?? now.microsecondsSinceEpoch.toString()).toString(),
          createdAt: DateTime.fromMillisecondsSinceEpoch((r['createdAtMs'] as int?) ?? now.millisecondsSinceEpoch),
          source: pkg,
          title: title.isEmpty ? pkg : title,
          body: body.isEmpty ? null : body,
          fingerprint: fp,
          lastSeenAt: now,
          count: 1,
          acknowledged: false,
        );
        byFp[fp] = item;
      } else {
        byFp[fp] = prev.copyWith(
          lastSeenAt: now,
          count: prev.count + 1,
        );
      }
    }

    final merged = byFp.values.toList()
      ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));

    await SignalStore.save(merged);

    kernel.observe(
      TwinEvent.actionPerformed(
        surface: 'device',
        actor: TwinActor.system,
        action: 'notifications_ingested',
        meta: {'count': rows.length},
      ),
    );
  }

  Future<void> _ingestUsage(TwinPlusKernel kernel) async {
    final enabled = await UsageStatsIngestor.isUsageAccessEnabled();
    if (!enabled) return;

    final prefs = await SharedPreferences.getInstance();
    final since = prefs.getInt(_kLastUsageFetchMs) ?? (DateTime.now().millisecondsSinceEpoch - 5 * 60 * 1000);

    final events = await UsageStatsIngestor.fetchUsageEvents(sinceEpochMs: since, maxEvents: 800);
    prefs.setInt(_kLastUsageFetchMs, DateTime.now().millisecondsSinceEpoch);

    if (events.isEmpty) return;

    kernel.observe(
      TwinEvent.actionPerformed(
        surface: 'device',
        actor: TwinActor.system,
        action: 'usage_events_ingested',
        meta: {'count': events.length},
      ),
    );

    // Lightweight: record the top packages in this window to preferences model
    // (the kernel can choose to learn or ignore; we keep payload small).
    final pkgs = <String, int>{};
    for (final e in events) {
      final p = (e['packageName'] ?? '').toString();
      if (p.isEmpty) continue;
      pkgs[p] = (pkgs[p] ?? 0) + 1;
    }

    final top = pkgs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topPkgs = top.take(8).map((e) => {'package': e.key, 'events': e.value}).toList(growable: false);

    kernel.observe(
      TwinEvent.actionPerformed(
        surface: 'device',
        actor: TwinActor.system,
        action: 'usage_window_summary',
        meta: {
          'sinceEpochMs': since,
          'top': topPkgs,
        },
        confidence: 0.7,
        privacy: TwinPrivacy.sensitiveRedacted,
      ),
    );
  }
}

/// Tiny helper to silence unawaited futures without importing package:pedantic.
void unawaited(Future<void> f) {}
