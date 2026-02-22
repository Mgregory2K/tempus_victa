// lib/services/learning/trust_engine.dart
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class TrustEngine {
  TrustEngine._();
  static final TrustEngine instance = TrustEngine._();

  bool _initialized = false;
  late File _file;

  // key format: "<type>::<id>"
  final Map<String, double> _scores = {};

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    final docs = await getApplicationDocumentsDirectory();
    final learningDir = Directory('${docs.path}/learning');
    if (!await learningDir.exists()) {
      await learningDir.create(recursive: true);
    }

    _file = File('${learningDir.path}/trust_scores.json');
    if (await _file.exists()) {
      final raw = await _file.readAsString();
      if (raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final k = '${entry.key}';
            final v = entry.value;
            if (v is num) _scores[k] = v.toDouble().clamp(0.0, 1.0);
          }
        }
      }
    } else {
      await _file.create(recursive: true);
      await _file.writeAsString(jsonEncode({}));
    }

    _initialized = true;
  }

  double getTrust(String entityType, String entityId, {double defaultValue = 0.50}) {
    final key = _k(entityType, entityId);
    return _scores[key] ?? defaultValue;
  }

  Future<void> reinforce({
    required String entityType,
    required String entityId,
    double delta = 0.02,
  }) async {
    if (!_initialized) await init();
    final key = _k(entityType, entityId);
    final cur = _scores[key] ?? 0.50;
    _scores[key] = (cur + delta).clamp(0.0, 1.0);
    await _persist();
  }

  Future<void> demote({
    required String entityType,
    required String entityId,
    double delta = 0.05,
  }) async {
    if (!_initialized) await init();
    final key = _k(entityType, entityId);
    final cur = _scores[key] ?? 0.50;
    _scores[key] = (cur - delta).clamp(0.0, 1.0);
    await _persist();
  }

  Future<void> _persist() async {
    try {
      await _file.writeAsString(jsonEncode(_scores), flush: true);
    } catch (_) {
      // swallow (learning must never crash UI)
    }
  }

  String _k(String t, String id) => '$t::$id';
}
