/// lib/services/engine/nodes/node.dart
///
/// A Node is a single step in an automation pipeline.
/// Nodes are pure-dart and can be used on-device.

import '../event_bus.dart';

class NodeContext {
  final TempusEvent event;

  /// Scratch space for nodes to pass data downstream.
  final Map<String, dynamic> bag;

  NodeContext({required this.event, Map<String, dynamic>? bag}) : bag = bag ?? {};
}

abstract class Node {
  String get name;

  /// Throws on fatal errors. Caller decides retry/backoff.
  Future<void> run(NodeContext ctx);
}
