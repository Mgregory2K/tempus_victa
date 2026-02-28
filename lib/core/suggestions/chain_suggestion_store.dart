import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ChainSuggestion {
  final String type;
  final String entityId;
  final int tsMs;

  const ChainSuggestion({
    required this.type,
    required this.entityId,
    required this.tsMs,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'entityId': entityId,
        'tsMs': tsMs,
      };

  static ChainSuggestion? fromJson(Map<String, dynamic> j) {
    final type = (j['type'] ?? '').toString();
    final entityId = (j['entityId'] ?? '').toString();
    final tsMs = (j['tsMs'] is int) ? j['tsMs'] as int : (int.tryParse('${j['tsMs']}') ?? 0);
    if (type.isEmpty || entityId.isEmpty) return null;
    return ChainSuggestion(type: type, entityId: entityId, tsMs: tsMs);
  }
}

class ChainSuggestionStore {
  static const _kKey = 'suggestion.chain.pending.v1';
  static const int _ttlMs = 10 * 60 * 1000;

  Future<void> setPending(ChainSuggestion s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(s.toJson()));
  }

  Future<ChainSuggestion?> peek() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return null;
      final s = ChainSuggestion.fromJson(j.cast<String, dynamic>());
      if (s == null) return null;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - s.tsMs > _ttlMs) {
        await clear();
        return null;
      }
      return s;
    } catch (_) {
      return null;
    }
  }

  Future<ChainSuggestion?> consume() async {
    final s = await peek();
    await clear();
    return s;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}
