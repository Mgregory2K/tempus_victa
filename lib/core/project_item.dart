class ProjectItem {
  final String id;
  final DateTime createdAt;
  final String name;

  const ProjectItem({
    required this.id,
    required this.createdAt,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'name': name,
      };

  static ProjectItem fromJson(Map<String, dynamic> j) => ProjectItem(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        name: (j['name'] as String?) ?? 'Project',
      );
}
