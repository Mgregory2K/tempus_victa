import 'dart:collection';

import 'jsonl_store.dart';

/// Append-only status store for Signals triage.
/// We do NOT delete signals. We only label them.
/// Storage: app documents dir / signal_triage.jsonl
///
/// Status values:
/// - inbox (default)
/// - filed (corked)
/// - vault (dismissed)
class SignalTriageStore {
  static const String _fileName = 'signal_triage.jsonl';
  final JsonlStore _store;

  SignalTriageStore({JsonlStore? store}) : _store = store ?? JsonlStore();

  Future<Map<String, String>> loadStatusBySignalId() async {
    final rows = await _store.readAll(_fileName);
    final Map<String, String> out = {};

    // last write wins (append-only log)
    for (final r in rows) {
      final sid = r['signalId'];
      final status = r['status'];
      if (sid is String && sid.isNotEmpty && status is String && status.isNotEmpty) {
        out[sid] = status;
      }
    }

    return UnmodifiableMapView(out);
  }

  Future<void> setStatus({
    required String signalId,
    required String status, // inbox|filed|vault
    String? reason,
  }) async {
    await _store.append(_fileName, <String, dynamic>{
      'signalId': signalId,
      'status': status,
      'atUtc': DateTime.now().toUtc().toIso8601String(),
      if (reason != null) 'reason': reason,
    });
  }
}
