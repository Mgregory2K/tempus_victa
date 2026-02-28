import 'decision_audit_store.dart';

/// Derives routing preferences from recorded routing decisions in [DecisionAuditStore].
///
/// This intentionally stays lightweight:
/// - local-only
/// - no DB schema changes
/// - uses the existing DecisionAudit stream as the source of truth
///
/// Action convention:
///   action = 'route_decision:<routeIntent>'
/// Examples:
///   route_decision:route_to_task
///   route_decision:route_to_corkboard
class RoutingDecisionStore {
  static final RoutingDecisionStore instance = RoutingDecisionStore._();

  RoutingDecisionStore._();

  final DecisionAuditStore _audit = DecisionAuditStore();

  /// surface -> routeIntent -> weight
  final Map<String, Map<String, double>> _weights = {};

  /// Rebuilds weights from the current audit log.
  Future<void> refresh() async {
    _weights.clear();
    final entries = await _audit.load();
    for (final e in entries) {
      final a = e.action;
      if (!a.startsWith('route_decision:')) continue;
      final surface = (e.surface ?? 'unknown').trim().isEmpty ? 'unknown' : e.surface!;
      final route = a.substring('route_decision:'.length).trim();
      if (route.isEmpty) continue;

      _weights.putIfAbsent(surface, () => {});
      _weights[surface]!.update(route, (v) => v + 1.0, ifAbsent: () => 1.0);
    }
  }

  Map<String, double> routeWeightsForSurface(String surface) {
    return Map<String, double>.from(_weights[surface] ?? const {});
  }

  /// Returns the best learned route intent for a surface (by weight).
  /// Falls back to [fallbackRouteIntent] if no evidence exists.
  String learnedRouteForSurface(String surface, {String fallbackRouteIntent = 'route_to_task'}) {
    final m = _weights[surface];
    if (m == null || m.isEmpty) return fallbackRouteIntent;

    double best = -1;
    String bestRoute = fallbackRouteIntent;
    for (final entry in m.entries) {
      if (entry.value > best) {
        best = entry.value;
        bestRoute = entry.key;
      }
    }
    return bestRoute;
  }
}
