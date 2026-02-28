import 'package:flutter/foundation.dart';

/// ZIP 13 — In-app dev trace (local-only).
///
/// Purpose:
/// - Give visibility into Doctrine planning/execution without polluting user surfaces.
/// - Acts as a simple ring buffer of lines.
///
/// Storage:
/// - In-memory only (clears on app restart).
/// - Controlled by Dev Mode toggle in AppSettingsStore.
class DevTraceStore {
  DevTraceStore._();
  static final DevTraceStore instance = DevTraceStore._();

  static const int _maxLines = 60;

  final ValueNotifier<List<String>> notifier = ValueNotifier<List<String>>(<String>[]);

  void add(String line) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final entry = '[$ts] $line';

    final current = List<String>.of(notifier.value);
    current.insert(0, entry);
    if (current.length > _maxLines) {
      current.removeRange(_maxLines, current.length);
    }
    notifier.value = current;
  }

  void clear() {
    notifier.value = <String>[];
  }
}
