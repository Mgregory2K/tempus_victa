import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Routing training window counters (local-only).
/// Purpose: show "Route This" choices only while the system is still learning,
/// then collapse to the learned default once the threshold is reached.
class RoutingCounterStore {
  static final RoutingCounterStore instance = RoutingCounterStore._();

  RoutingCounterStore._();

  static const int threshold = 25;
  static const String _kKey = 'doctrine.routingCounters.v1';

  /// Counters are stored as: { surface: { intent: count } }
  final Map<String, Map<String, double>> _counters = {};

  /// Must be called once during app startup (or lazily before use).
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      for (final entry in decoded.entries) {
        final surface = entry.key.toString();
        final v = entry.value;
        if (v is! Map) continue;
        _counters[surface] = {};
        for (final e2 in v.entries) {
          final intent = e2.key.toString();
          final numVal = e2.value;
          final d = (numVal is num) ? numVal.toDouble() : (double.tryParse('$numVal') ?? 0.0);
          _counters[surface]![intent] = d;
        }
      }
    } catch (_) {
      // ignore corrupt storage
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(_counters));
  }

  /// Total routing decisions for a surface (used to gate the training window).
  static const String intentRouteTotal = 'route_total';

  /// Route intents (per-surface).
  static const String intentRouteToTask = 'route_to_task';
  static const String intentRouteToCorkboard = 'route_to_corkboard';
  static const String intentRouteToRecycle = 'route_to_recycle';
  static const String intentRouteToAcknowledge = 'route_to_acknowledge';

  void _bump(String surface, String intent, double delta) {
    _counters.putIfAbsent(surface, () => {});
    _counters[surface]!.update(
      intent,
      (value) => value + delta,
      ifAbsent: () => delta,
    );
  }

  Future<void> increment(String surface, String intent) async {
    _bump(surface, intent, 1);
    await _persist();
  }

  Future<void> reinforce(String surface, String intent) async {
    _bump(surface, intent, 0.1);
    await _persist();
  }

  double getCount(String surface, String intent) {
    return _counters[surface]?[intent] ?? 0;
  }

  bool isTrainingWindow(String surface) {
    return getCount(surface, intentRouteTotal) < threshold;
  }

  /// Records a routing decision (increments total + chosen route, lightly reinforces).
  Future<void> recordRouteDecision(String surface, String routeIntent) async {
    _bump(surface, intentRouteTotal, 1);
    _bump(surface, routeIntent, 1);
    // small reinforcement to nudge tie-breakers without runaway growth
    _bump(surface, routeIntent, 0.05);
    await _persist();
  }

  /// Picks the learned default route for a surface.
  /// If no data exists, returns [intentRouteToTask].
  String learnedDefaultRoute(String surface) {
    final m = _counters[surface];
    if (m == null || m.isEmpty) return intentRouteToTask;

    double best = -1;
    String bestIntent = intentRouteToTask;
    for (final k in [
      intentRouteToTask,
      intentRouteToCorkboard,
      intentRouteToRecycle,
      intentRouteToAcknowledge,
    ]) {
      final v = m[k] ?? 0;
      if (v > best) {
        best = v;
        bestIntent = k;
      }
    }
    return bestIntent;
  }
}
