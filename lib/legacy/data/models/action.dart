class Action {
  final int id;
  final String title;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final DateTime? dueDate;
  final int? missionId;

  Action({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.createdAt,
    required this.modifiedAt,
    this.dueDate,
    this.missionId,
  });
}
