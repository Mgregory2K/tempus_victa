import 'dart:async';

import 'package:flutter/services.dart';

import '../../data/repositories/signal_repo.dart';
import '../logging/jsonl_logger.dart';

/// Android share-sheet ingestion.
///
/// This is a core ingestion source: everything shared in becomes a Signal (inbox).
class ShareIntentService {
  ShareIntentService._();
  static final ShareIntentService instance = ShareIntentService._();

  static const EventChannel _channel = EventChannel('tempus/share_intent');
  static const MethodChannel _methods = MethodChannel('tempus/share_methods');

  StreamSubscription? _sub;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    // Pull initial shared text (if app launched from share).
    try {
      final initial = await _methods.invokeMethod<String>('getInitialSharedText');
      if (initial != null && initial.trim().isNotEmpty) {
        await _ingestText(initial.trim(), source: 'android_share_initial');
      }
    } catch (_) {
      // ignore (platform may not support yet)
    }

    _sub = _channel.receiveBroadcastStream().listen((event) async {
      try {
        final m = (event as Map).cast<String, dynamic>();
        final text = (m['text'] as String?)?.trim();
        if (text == null || text.isEmpty) return;
        await _ingestText(text, source: (m['source'] as String?) ?? 'android_share');
      } catch (_) {
        // ignore malformed events
      }
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }

  Future<void> _ingestText(String text, {required String source}) async {
    final s = await SignalRepo.instance.create(
      kind: 'share',
      source: source,
      text: text,
      status: 'inbox',
      confidence: 0.6,
      weight: 0.2,
    );
    await JsonlLogger.instance.log('ingest_share', {'id': s.id, 'source': source});
  }
}