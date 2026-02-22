import 'dart:collection';

import 'jsonl_store.dart';

/// Append-only "extra metadata" store for Signals.
/// This avoids DB migrations and keeps expansion cheap.
///
/// Storage: app documents dir / signal_extra.jsonl
///
/// Each entry:
/// {
///   "signalId": "<id>",
///   "extra": { ... arbitrary json ... },
///   "atUtc": "2026-02-17T06:12:00.000Z"
/// }
class SignalExtraStore {
  static const String _fileName = 'signal_extra.jsonl';
  final JsonlStore _store;

  SignalExtraStore({JsonlStore? store}) : _store = store ?? JsonlStore();

  /// Returns the latest extra map for a signalId (last-write-wins).
  Future<Map<String, dynamic>?> getLatestExtra(String signalId) async {
    final rows = await _store.readAll(_fileName);

    Map<String, dynamic>? latest;
    for (final r in rows) {
      final sid = r['signalId'];
      final extra = r['extra'];

      if (sid == signalId && extra is Map) {
        // Normalize to <String, dynamic>
        final m = <String, dynamic>{};
        for (final entry in extra.entries) {
          final k = entry.key;
          if (k is String) m[k] = entry.value;
        }
        latest = m;
      }
    }

    if (latest == null) return null;
    return UnmodifiableMapView(latest);
  }

  /// Appends a new extra payload for this signalId.
  /// Last-write-wins semantics.
  Future<void> setExtra({
    required String signalId,
    required Map<String, dynamic> extra,
  }) async {
    await _store.append(_fileName, <String, dynamic>{
      'signalId': signalId,
      'extra': extra,
      'atUtc': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
