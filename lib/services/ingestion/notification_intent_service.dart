import 'dart:async';

import 'package:flutter/services.dart';

import '../../data/repositories/signal_repo.dart';
import '../logging/jsonl_logger.dart';

/// Notification ingestion via Android NotificationListenerService.
///
/// Note: user must enable Notification Access for the app in Android settings.
/// When enabled, notifications posted while the app is running will stream into Flutter.
class NotificationIntentService {
  NotificationIntentService._();
  static final NotificationIntentService instance = NotificationIntentService._();

  static const EventChannel _channel = EventChannel('tempus/notification_intent');

  StreamSubscription? _sub;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _sub = _channel.receiveBroadcastStream().listen((event) async {
      try {
        final m = (event as Map).cast<String, dynamic>();
        final pkg = (m['package'] as String?) ?? '';
        final title = (m['title'] as String?) ?? '';
        final body = (m['text'] as String?) ?? '';
        final text = [title, body].where((e) => e.trim().isNotEmpty).join(' — ').trim();
        if (text.isEmpty) return;

        final s = await SignalRepo.instance.create(
          kind: 'notification',
          source: 'android_notification:$pkg',
          text: text,
          status: 'inbox',
          confidence: 0.7,
          weight: 0.4,
        );
        await JsonlLogger.instance.log('ingest_notification', {'id': s.id, 'pkg': pkg});
      } catch (_) {
        // ignore
      }
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }
}