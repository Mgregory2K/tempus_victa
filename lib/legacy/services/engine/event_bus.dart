/// lib/services/engine/event_bus.dart
///
/// Conception alignment: Event → Rule → Action.
///
/// This is a LOCAL-FIRST in-memory event bus with optional persistence hooks.
/// It is intentionally dependency-free so it can be embedded in mobile, desktop,
/// or server runtimes.
///
/// NOTE: This file is additive only. It is not wired into the current app yet.

import 'dart:async';

/// A single event emitted by the system.
class TempusEvent {
  final String type;
  final DateTime occurredAtUtc;
  final Map<String, dynamic> payload;

  TempusEvent({
    required this.type,
    DateTime? occurredAtUtc,
    Map<String, dynamic>? payload,
  })  : occurredAtUtc = (occurredAtUtc ?? DateTime.now().toUtc()),
        payload = payload ?? const {};

  @override
  String toString() => 'TempusEvent(type=$type, occurredAtUtc=$occurredAtUtc, payloadKeys=${payload.keys.length})';
}

/// A lightweight pub/sub bus.
class EventBus {
  final StreamController<TempusEvent> _c = StreamController.broadcast();

  Stream<TempusEvent> get stream => _c.stream;

  void emit(TempusEvent e) {
    if (_c.isClosed) return;
    _c.add(e);
  }

  StreamSubscription<TempusEvent> listen(void Function(TempusEvent) onData) {
    return stream.listen(onData);
  }

  Future<void> dispose() async {
    await _c.close();
  }
}
