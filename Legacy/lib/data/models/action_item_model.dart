import 'dart:convert';

/// Canonical Action lifecycle.
///
/// Textbook alignment:
/// - Capture first (INBOX)
/// - Route later (ACTIVE)
/// - Complete (DONE)
/// - Remove from surface without deleting history (ARCHIVED)
///
/// Back-compat:
/// Older builds wrote status = "open"; we treat that as [active].
enum ActionStatus { inbox, active, done, archived }

class ActionItem {
  final String id;
  final DateTime createdAt;
  final DateTime capturedAt;
  final DateTime modifiedAt;
  final String title;
  final String? notes;
  final DateTime? dueAt;
  final ActionStatus status;

  // provenance
  final String? sourceCorkId;
  final String? sourceSignalId;
  final String? source;

  const ActionItem({
    required this.id,
    required this.createdAt,
    required this.capturedAt,
    required this.modifiedAt,
    required this.title,
    this.notes,
    this.dueAt,
    this.status = ActionStatus.inbox,
    this.sourceCorkId,
    this.sourceSignalId,
    this.source,
  });

  ActionItem copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? capturedAt,
    DateTime? modifiedAt,
    String? title,
    String? notes,
    DateTime? dueAt,
    ActionStatus? status,
    String? sourceCorkId,
    String? sourceSignalId,
    String? source,
  }) {
    return ActionItem(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      capturedAt: capturedAt ?? this.capturedAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dueAt: dueAt ?? this.dueAt,
      status: status ?? this.status,
      sourceCorkId: sourceCorkId ?? this.sourceCorkId,
      sourceSignalId: sourceSignalId ?? this.sourceSignalId,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'modifiedAt': modifiedAt.toUtc().toIso8601String(),
        'title': title,
        'notes': notes,
        'dueAt': dueAt?.toUtc().toIso8601String(),
        'status': status.name,
        'sourceCorkId': sourceCorkId,
        'sourceSignalId': sourceSignalId,
        'source': source,
      };

  static ActionStatus _statusFrom(dynamic v) {
    final s = (v ?? 'open').toString();
    if (s == 'inbox') return ActionStatus.inbox;
    if (s == 'active') return ActionStatus.active;
    if (s == 'done') return ActionStatus.done;
    if (s == 'archived') return ActionStatus.archived;

    // Back-compat
    if (s == 'open') return ActionStatus.active;

    return ActionStatus.inbox;
  }

  static ActionItem fromJson(Map<String, dynamic> j) {
    final created = DateTime.tryParse((j['createdAt'] ?? '').toString())?.toUtc() ??
        DateTime.now().toUtc();
    final captured = DateTime.tryParse((j['capturedAt'] ?? '').toString())?.toUtc() ??
        created;
    final modified = DateTime.tryParse((j['modifiedAt'] ?? '').toString())?.toUtc() ??
        created;

    return ActionItem(
      id: (j['id'] ?? '').toString(),
      createdAt: created,
      capturedAt: captured,
      modifiedAt: modified,
      title: (j['title'] ?? '').toString(),
      notes: j['notes']?.toString(),
      dueAt: j['dueAt'] == null
          ? null
          : DateTime.tryParse(j['dueAt'].toString())?.toUtc(),
      status: _statusFrom(j['status']),
      sourceCorkId: j['sourceCorkId']?.toString(),
      sourceSignalId: j['sourceSignalId']?.toString(),
      source: j['source']?.toString(),
    );
  }

  String toJsonLine() => jsonEncode(toJson());

  static ActionItem? tryFromJsonLine(String line) {
    try {
      final d = jsonDecode(line);
      if (d is Map<String, dynamic>) return fromJson(d);
    } catch (_) {}
    return null;
  }
}