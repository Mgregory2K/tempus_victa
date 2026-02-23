class ProjectItem {
  final String id;
  final DateTime createdAt;
  final String name;

  /// Optional Jira-style key (e.g., TV, OPS, HOME)
  final String? key;

  const ProjectItem({
    required this.id,
    required this.createdAt,
    required this.name,
    this.key,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'name': name,
        if (key != null) 'key': key,
      };

  static ProjectItem fromJson(Map<String, dynamic> j) => ProjectItem(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        name: (j['name'] as String?) ?? '',
        key: j['key'] as String?,
      );
}
