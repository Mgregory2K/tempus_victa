class ProjectItem {
  final String id;
  final DateTime createdAt;
  final String name;

  final bool isCompleted;
  final DateTime? completedAt;

  /// Optional Jira-style key (e.g., TV, OPS, HOME)
  final String? key;

  const ProjectItem({
    required this.id,
    required this.createdAt,
    required this.name,
    this.key,
    this.isCompleted = false,
    this.completedAt,
  });

  ProjectItem copyWith({
    String? id,
    DateTime? createdAt,
    String? name,
    String? key,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return ProjectItem(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      name: name ?? this.name,
      key: key ?? this.key,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'name': name,
        if (key != null) 'key': key,
        'isCompleted': isCompleted,
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      };

  static ProjectItem fromJson(Map<String, dynamic> j) => ProjectItem(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        name: (j['name'] as String?) ?? '',
        key: j['key'] as String?,
      );
}
