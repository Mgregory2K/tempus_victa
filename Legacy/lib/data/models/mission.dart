import 'package:mobile/data/db/app_db.dart';

class Mission {
  final int id;
  final String name;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime modifiedAt;

  Mission({
    required this.id,
    required this.name,
    required this.isCompleted,
    required this.createdAt,
    required this.modifiedAt,
  });

  static Mission fromDb(MissionData mission) {
    return Mission(
      id: mission.id,
      name: mission.name,
      isCompleted: mission.isCompleted,
      createdAt: mission.createdAt,
      modifiedAt: mission.modifiedAt,
    );
  }
}
