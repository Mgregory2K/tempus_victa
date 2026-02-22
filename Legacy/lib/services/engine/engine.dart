/// lib/services/engine/engine.dart
///
/// Conception alignment: Event → Rule → Action.
///
/// Engine subscribes to the EventBus and runs enabled rules that match.
/// This is intentionally simple: deterministic execution, no background threads.

import 'dart:async';

import 'event_bus.dart';
import 'rules/rule.dart';
import 'nodes/node.dart';

class EngineDiag {
  final DateTime atUtc;
  final String message;
  EngineDiag(this.message) : atUtc = DateTime.now().toUtc();

  @override
  String toString() => '[${atUtc.toIso8601String()}] $message';
}

class AutomationEngine {
  final EventBus bus;
  final List<Rule> rules;
  final void Function(EngineDiag) onDiag;

  StreamSubscription<TempusEvent>? _sub;

  AutomationEngine({
    required this.bus,
    required this.rules,
    required this.onDiag,
  });

  void start() {
    _sub ??= bus.listen(_onEvent);
    onDiag(EngineDiag('engine started; rules=${rules.length}'));
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    onDiag(EngineDiag('engine stopped'));
  }

  Future<void> _onEvent(TempusEvent e) async {
    for (final r in rules) {
      if (!r.enabled) continue;
      if (!r.matches(e)) continue;

      onDiag(EngineDiag('rule matched: ${r.name} (${r.id}) for event=${e.type}'));

      final ctx = NodeContext(event: e);
      for (final n in r.nodes) {
        try {
          await n.run(ctx);
        } catch (ex) {
          onDiag(EngineDiag('node failed: ${n.name} | $ex'));
          rethrow;
        }
      }
    }
  }
}
