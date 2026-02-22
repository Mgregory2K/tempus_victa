// Tempus Vista rebuild - generated 2026-02-21
// Local-first, Android-first.


class Task {
  final String id;
  final String title;
  final String? details;
  final String status; // inbox|open|done
  final String source;
  final String? signalId;
  final DateTime? dueAtUtc;
  final DateTime capturedAtUtc;
  final DateTime createdAtUtc;
  final DateTime modifiedAtUtc;

  Task({
    required this.id,
    required this.title,
    required this.status,
    required this.source,
    required this.capturedAtUtc,
    required this.createdAtUtc,
    required this.modifiedAtUtc,
    this.details,
    this.signalId,
    this.dueAtUtc,
  });

  Map<String, Object?> toRow() => {
        'id': id,
        'title': title,
        'details': details,
        'status': status,
        'source': source,
        'signal_id': signalId,
        'due_at_utc': dueAtUtc?.millisecondsSinceEpoch,
        'captured_at_utc': capturedAtUtc.millisecondsSinceEpoch,
        'created_at_utc': createdAtUtc.millisecondsSinceEpoch,
        'modified_at_utc': modifiedAtUtc.millisecondsSinceEpoch,
      };

  static Task fromRow(Map<String, Object?> r) => Task(
        id: r['id'] as String,
        title: (r['title'] as String?) ?? '',
        details: r['details'] as String?,
        status: (r['status'] as String?) ?? 'open',
        source: (r['source'] as String?) ?? 'unknown',
        signalId: r['signal_id'] as String?,
        dueAtUtc: (r['due_at_utc'] as int?) == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(r['due_at_utc'] as int, isUtc: true),
        capturedAtUtc: DateTime.fromMillisecondsSinceEpoch((r['captured_at_utc'] as int?) ?? 0, isUtc: true),
        createdAtUtc: DateTime.fromMillisecondsSinceEpoch((r['created_at_utc'] as int?) ?? 0, isUtc: true),
        modifiedAtUtc: DateTime.fromMillisecondsSinceEpoch((r['modified_at_utc'] as int?) ?? 0, isUtc: true),
      );
}
