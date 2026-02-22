class TaskModel {
  final int? id;
  final String title;
  final String? description;
  final bool completed;
  final bool recycled;
  final DateTime createdAt;

  TaskModel({
    this.id,
    required this.title,
    this.description,
    this.completed = false,
    this.recycled = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'completed': completed ? 1 : 0,
      'recycled': recycled ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      completed: map['completed'] == 1,
      recycled: map['recycled'] == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
