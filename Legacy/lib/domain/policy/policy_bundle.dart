// PolicyBundle (Phase 1 stub)
//
// Future: combine deterministic rules + learned weights + user settings.
// For now: wraps the deterministic PolicyEngine.

import 'policy_engine.dart';

class PolicyBundle {
  final PolicyEngine engine;

  const PolicyBundle({this.engine = const PolicyEngine()});
}
