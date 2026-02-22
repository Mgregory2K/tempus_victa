/// lib/services/engine/nodes/log_node.dart
///
/// Minimal observability node: emits a diagnostic line.

import 'node.dart';

typedef LogSink = void Function(String line);

class LogNode implements Node {
  final String message;
  final LogSink sink;

  LogNode({required this.message, required this.sink});

  @override
  String get name => 'LogNode';

  @override
  Future<void> run(NodeContext ctx) async {
    sink('[${DateTime.now().toUtc().toIso8601String()}] $message | event=${ctx.event.type}');
  }
}
