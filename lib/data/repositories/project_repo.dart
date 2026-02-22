// Tempus Victa - Project repository (sqflite)

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/app_db.dart';
import '../models/project.dart';

class ProjectRepo {
  ProjectRepo._();
  static final ProjectRepo instance = ProjectRepo._();
  static const _uuid = Uuid();

  Future<List<Project>> list({String status = 'active'}) async {
    final d = await AppDb.instance.db;
    final rows = await d.query('projects', where: 'status = ?', whereArgs: [status], orderBy: 'modified_at_utc DESC');
    return rows.map(Project.fromRow).toList();
  }

  Future<Project> create({required String title}) async {
    final now = DateTime.now().toUtc();
    final p = Project(
      id: _uuid.v4(),
      title: title,
      status: 'active',
      createdAtUtc: now,
      modifiedAtUtc: now,
    );
    final d = await AppDb.instance.db;
    await d.insert('projects', p.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    return p;
  }

  Future<void> setStatus(String id, String status) async {
    final d = await AppDb.instance.db;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await d.update('projects', {'status': status, 'modified_at_utc': now}, where: 'id = ?', whereArgs: [id]);
  }
}
