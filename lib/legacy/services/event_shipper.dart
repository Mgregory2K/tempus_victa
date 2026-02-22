import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'jsonl_store.dart';

/// Ships locally-captured notifications to the backend.
///
/// Doctrine:
/// - Local JSONL is canonical.
/// - Backend is best-effort.
/// - If POST fails, write to unsent_events.jsonl.
/// - Never crash the app if backend is unreachable.
///
/// This shipper:
/// - reads raw_notifications.jsonl
/// - posts new lines (cursor-based)
/// - persists cursor so it survives restarts
class EventShipper {
  static final EventShipper instance = EventShipper._();
  EventShipper._();

  final JsonlStore _store = JsonlStore();

  Timer? _timer;
  bool _busy = false;
  int _lastLine = 0;

  bool get running => _timer != null;

  static const String _stateFile = 'shipper_state.json';
  static const String _rawFile = 'raw_notifications.jsonl';
  static const String _unsentFile = 'unsent_events.jsonl';

  Future<void> start() async {
    if (running) return;
    await _loadState();

    // Ship quickly, but not aggressively.
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_busy) return;
      _busy = true;
      _shipOnce().whenComplete(() => _busy = false);
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _loadState() async {
    try {
      final f = await _store.getFile(_stateFile);
      if (!await f.exists()) {
        _lastLine = 0;
        return;
      }
      final txt = await f.readAsString();
      final m = jsonDecode(txt) as Map<String, dynamic>;
      final v = m['lastLine'];
      _lastLine = v is int ? v : int.tryParse(v.toString()) ?? 0;
      if (_lastLine < 0) _lastLine = 0;
    } catch (_) {
      _lastLine = 0;
    }
  }

  Future<void> _saveState() async {
    try {
      final f = await _store.getFile(_stateFile);
      await f.parent.create(recursive: true);
      final obj = {
        'lastLine': _lastLine,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await f.writeAsString(jsonEncode(obj), flush: true);
    } catch (_) {
      // Never crash.
    }
  }

  Future<void> _shipOnce() async {
    final cfg = await AppConfig.load();
    final baseUrl = cfg.baseUrl.trim();
    if (baseUrl.isEmpty) return;

    final rawFile = await _store.getFile(_rawFile);
    if (!await rawFile.exists()) return;

    List<String> lines;
    try {
      lines = await rawFile.readAsLines();
    } catch (e) {
      debugPrint('EventShipper: read raw failed: $e');
      return;
    }

    if (_lastLine > lines.length) {
      // File cleared/rotated.
      _lastLine = 0;
    }

    final newLines = lines.sublist(_lastLine);
    if (newLines.isEmpty) return;

    for (final line in newLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        _lastLine++;
        continue;
      }

      Map<String, dynamic> raw;
      try {
        raw = jsonDecode(trimmed) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('EventShipper: bad JSON line: $e');
        _lastLine++;
        continue;
      }

      final payload = <String, dynamic>{
        'source': 'android_notification',
        'raw_content': raw,
        'device': {
          'platform': 'android',
          'device_label': 'phone',
        },
      };

      final ok = await _postEvent(
        baseUrl: baseUrl,
        jwt: cfg.jwt,
        payload: payload,
      );

      if (!ok) {
        await _store.append(_unsentFile, {
          'ts': DateTime.now().toIso8601String(),
          'reason': 'post_failed',
          'baseUrl': baseUrl,
          'payload': payload,
        });
      }

      _lastLine++;
      await _saveState();
    }
  }

  Future<bool> _postEvent({
    required String baseUrl,
    required String? jwt,
    required Map<String, dynamic> payload,
  }) async {
    final uri = Uri.parse('$baseUrl/events');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    final token = (jwt ?? '').trim();
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final r = await http
          .post(uri, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 2));

      if (r.statusCode == 200) return true;
      debugPrint('EventShipper: post failed ${r.statusCode}: ${r.body}');
      return false;
    } catch (e) {
      debugPrint('EventShipper: post exception: $e');
      return false;
    }
  }
}
