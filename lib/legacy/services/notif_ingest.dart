import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'tempus_api.dart';

// This class listens for Android notifications.
// When a notification comes in, we:
// 1) save it locally (always)
// 2) try to send it to the backend (best-effort)
// If backend fails, we do NOT crash.
class NotifIngest {
  static const MethodChannel _methods = MethodChannel('tempus/notif_methods');
  static const EventChannel _events = EventChannel('tempus/notif_events');

  final TempusApi _api = TempusApi();
  StreamSubscription? _sub;

  Future<File> _rawLogFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/raw_notifications.jsonl');
  }

  Future<File> _unsentLogFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/unsent_events.jsonl');
  }

  Future<void> openNotificationAccessSettings() async {
    await _methods.invokeMethod('openNotificationAccessSettings');
  }

  Future<bool> isAccessEnabled() async {
    final v = await _methods.invokeMethod('isNotificationAccessEnabled');
    return v == true;
  }

  Future<void> start() async {
    if (_sub != null) return;

    _sub = _events.receiveBroadcastStream().listen((dynamic data) async {
      try {
        final file = await _rawLogFile();
        final line = jsonEncode(data);
        await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
      } catch (_) {}

      try {
        if (data is Map) {
          final ok = await _api.ingestEvent(
            source: 'android_notification',
            raw: Map<String, dynamic>.from(data),
          );

          if (!ok) {
            final f = await _unsentLogFile();
            final record = {
              'ts': DateTime.now().toIso8601String(),
              'reason': 'backend_ingest_failed',
              'raw': data,
            };
            await f.writeAsString(
              '${jsonEncode(record)}\n',
              mode: FileMode.append,
              flush: true,
            );
          }
        }
      } catch (_) {}
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
