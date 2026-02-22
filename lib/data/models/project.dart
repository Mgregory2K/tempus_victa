// Tempus Victa - Project model (sqflite)

class Project {
  final String id;
  final String title;
  final String status; // active, done
  final DateTime createdAtUtc;
  final DateTime modifiedAtUtc;

  const Project({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAtUtc,
    required this.modifiedAtUtc,
  });

  factory Project.fromRow(Map<String, Object?> r) {
    return Project(
      id: (r['id'] ?? '').toString(),
      title: (r['title'] ?? '').toString(),
      status: (r['status'] ?? 'active').toString(),
      createdAtUtc: DateTime.fromMillisecondsSinceEpoch((r['created_at_utc'] as int?) ?? 0, isUtc: true),
      modifiedAtUtc: DateTime.fromMillisecondsSinceEpoch((r['modified_at_utc'] as int?) ?? 0, isUtc: true),
    );
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'title': title,
        'status': status,
        'created_at_utc': createdAtUtc.millisecondsSinceEpoch,
        'modified_at_utc': modifiedAtUtc.millisecondsSinceEpoch,
      };
}
