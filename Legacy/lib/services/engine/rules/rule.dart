/// lib/services/engine/rules/rule.dart
///
/// A deterministic automation rule:
/// - matches incoming events
/// - optionally evaluates conditions
/// - outputs one or more actions

import '../event_bus.dart';
import '../nodes/node.dart';

typedef EventPredicate = bool Function(TempusEvent e);

class Rule {
  final String id;
  final String name;
  final bool enabled;

  /// Quick event filter.
  final EventPredicate matches;

  /// Action graph / pipeline (nodes run in order).
  final List<Node> nodes;

  const Rule({
    required this.id,
    required this.name,
    required this.enabled,
    required this.matches,
    required this.nodes,
  });
}
