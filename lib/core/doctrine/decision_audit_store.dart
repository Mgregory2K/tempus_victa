import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DecisionAuditEntry {
  final String decisionId;
  final String action;
  final double confidence;
  final int tsMs;
  final String? surface;
  final String? entityType;
  final String? entityId;

  const DecisionAuditEntry({
    required this.decisionId,
    required this.action,
    required this.confidence,
    required this.tsMs,
    this.surface,
    this.entityType,
    this.entityId,
  });

  Map<String, dynamic> toJson() => {
        'decisionId': decisionId,
        'action': action,
        'confidence': confidence,
        'tsMs': tsMs,
        'surface': surface,
        'entityType': entityType,
        'entityId': entityId,
      };

  static DecisionAuditEntry fromJson(Map<String, dynamic> j) {
    return DecisionAuditEntry(
      decisionId: (j['decisionId'] ?? '').toString(),
      action: (j['action'] ?? '').toString(),
      confidence: (j['confidence'] is num) ? (j['confidence'] as num).toDouble() : (double.tryParse('${j['confidence']}') ?? 0.5),
      tsMs: (j['tsMs'] is int) ? j['tsMs'] as int : (int.tryParse('${j['tsMs']}') ?? 0),
      surface: (j['surface'] == null) ? null : (j['surface'] as String),
      entityType: (j['entityType'] == null) ? null : (j['entityType'] as String),
      entityId: (j['entityId'] == null) ? null : (j['entityId'] as String),
    );
  }
}

/// ZIP 26 — Decision auditing (local-only).
/// Stores the last N doctrine decisions for provenance/debug, in SharedPreferences.
class DecisionAuditStore {
  static const _kKey = 'doctrine.decisionAudit.v1';
  static const int _max = 200;

  Future<List<DecisionAuditEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => DecisionAuditEntry.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<void> add(DecisionAuditEntry e) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (await load()).toList(growable: true);
    current.insert(0, e);
    if (current.length > _max) current.removeRange(_max, current.length);
    await prefs.setString(_kKey, jsonEncode(current.map((x) => x.toJson()).toList()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}
