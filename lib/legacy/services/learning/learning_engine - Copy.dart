import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Tempus Victa — Learning Engine (local-first, silent)
/// Right now: safe, minimal, compile-proof.
/// - No external deps
/// - No file IO
/// - Keeps a small in-memory ring buffer for debugging
class LearningEngine {
  LearningEngine._();
  static final LearningEngine instance = LearningEngine._();

  /// Back-compat (so `LearningEngine.I` won't explode if you used it somewhere)
  static LearningEngine get I => instance;

  bool _initialized = false;

  // Small local ring buffer (keeps last N events)
  static const int _cap = 500;
  final List<Map<String, dynamic>> _events = <Map<String, dynamic>>[];

  Future<void> init() async {
    _initialized = true;
    recordTelemetry(
      event: 'learning_init',
      surface: 'app',
      data: {'kReleaseMode': kReleaseMode},
    );
  }

  bool get isInitialized => _initialized;

  List<Map<String, dynamic>> get recentEvents =>
      List.unmodifiable(_events.reversed);

  void recordTelemetry({
    required String event,
    String? surface,
    String? module,
    String? source,
    String? entityType,
    String? entityId,
    double? weight,
    DateTime? at,
    Map<String, dynamic>? data,
  }) {
    _push({
      'type': 'telemetry',
      'ts': (at ?? DateTime.now()).toUtc().toIso8601String(),
      'event': event,
      if (surface != null) 'surface': surface,
      if (module != null) 'module': module,
      if (source != null) 'source': source,
      if (entityType != null) 'entityType': entityType,
      if (entityId != null) 'entityId': entityId,
      if (weight != null) 'weight': weight,
      if (data != null) 'data': data,
    });
  }

  void recordIntent({
    required String intent,
    String? text,
    String? surface,
    String? module,
    String? sender,
    double? confidence,
    double? urgency,
    DateTime? at,
    List<Map<String, dynamic>>? entities,
    Map<String, dynamic>? data,
  }) {
    _push({
      'type': 'intent',
      'ts': (at ?? DateTime.now()).toUtc().toIso8601String(),
      'intent': intent,
      if (text != null) 'text': text,
      if (surface != null) 'surface': surface,
      if (module != null) 'module': module,
      if (sender != null) 'sender': sender,
      if (confidence != null) 'confidence': confidence,
      if (urgency != null) 'urgency': urgency,
      if (entities != null) 'entities': entities,
      if (data != null) 'data': data,
    });
  }

  void _push(Map<String, dynamic> e) {
    if (_events.length >= _cap) _events.removeAt(0);
    _events.add(e);

    // Silent by default, but still visible in debug console.
    if (!kReleaseMode) {
      debugPrint('[LEARN] ${jsonEncode(e)}');
    }
  }
}
