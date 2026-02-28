import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// ZIP 36 — User-owned routing overrides (local-only).
///
/// Rules are explicit user choices and ALWAYS override Twin+ learned routing.
///
/// Current scope: Signal source package => default route target.
enum RouteTarget {
  none,
  tasks,
  corkboard,
  recycle,
}

class RoutingRule {
  final String source; // package name, matches SignalItem.source
  final RouteTarget target;
  final int updatedAtMs;

  const RoutingRule({
    required this.source,
    required this.target,
    required this.updatedAtMs,
  });

  Map<String, dynamic> toJson() => {
        'source': source,
        'target': target.name,
        'updatedAtMs': updatedAtMs,
      };

  static RoutingRule? fromJson(Map<String, dynamic> j) {
    final source = (j['source'] ?? '').toString();
    final targetRaw = (j['target'] ?? '').toString();
    final updatedAtMs = (j['updatedAtMs'] is int) ? j['updatedAtMs'] as int : (int.tryParse('${j['updatedAtMs']}') ?? 0);
    if (source.trim().isEmpty) return null;
    final target = RouteTarget.values.firstWhere(
      (e) => e.name == targetRaw,
      orElse: () => RouteTarget.none,
    );
    return RoutingRule(source: source, target: target, updatedAtMs: updatedAtMs);
  }
}

class RoutingRuleStore {
  static const String _kKey = 'tempus.routing_rules.v1';

  Future<List<RoutingRule>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return const <RoutingRule>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <RoutingRule>[];
      final out = <RoutingRule>[];
      for (final x in decoded) {
        if (x is Map) {
          final r = RoutingRule.fromJson(x.cast<String, dynamic>());
          if (r != null) out.add(r);
        }
      }
      return out;
    } catch (_) {
      return const <RoutingRule>[];
    }
  }

  Future<void> save(List<RoutingRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(rules.map((e) => e.toJson()).toList());
    await prefs.setString(_kKey, encoded);
  }

  Future<RoutingRule?> ruleForSource(String source) async {
    final rules = await load();
    try {
      return rules.firstWhere((r) => r.source == source);
    } catch (_) {
      return null;
    }
  }

  Future<void> setRule(String source, RouteTarget target) async {
    final rules = (await load()).toList(growable: true);
    rules.removeWhere((r) => r.source == source);
    if (target != RouteTarget.none) {
      rules.add(
        RoutingRule(
          source: source,
          target: target,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
    await save(rules);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}
