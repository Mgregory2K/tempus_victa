// Tempus Vista rebuild - generated 2026-02-21
// Local-first, Android-first.


import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/app_db.dart';
import '../models/task.dart';

class TaskRepo {
  TaskRepo._();
  static final TaskRepo instance = TaskRepo._();
  static const _uuid = Uuid();

  Future<List<Task>> list({String status = 'open'}) async {
    final d = await AppDb.instance.db;
    final rows = await d.query(
      'tasks',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'captured_at_utc DESC',
      limit: 500,
    );
    return rows.map(Task.fromRow).toList();
  }

  Future<Task> create({
    required String title,
    String? details,
    String status = 'open',
    required String source,
    String? signalId,
    DateTime? dueAtUtc,
    DateTime? capturedAtUtc,
  }) async {
    final now = DateTime.now().toUtc();
    final cap = capturedAtUtc ?? now;
    final t = Task(
      id: _uuid.v4(),
      title: title,
      details: details,
      status: status,
      source: source,
      signalId: signalId,
      dueAtUtc: dueAtUtc,
      capturedAtUtc: cap,
      createdAtUtc: now,
      modifiedAtUtc: now,
    );
    final d = await AppDb.instance.db;
    await d.insert('tasks', t.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    return t;
  }

  Future<void> setStatus(String id, String status) async {
    final d = await AppDb.instance.db;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await d.update('tasks', {'status': status, 'modified_at_utc': now}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Task>> search(String query, {int limit = 10}) async {
    final q = query.trim();
    if (q.isEmpty) return const <Task>[];
    final d = await AppDb.instance.db;
    final rows = await d.query(
      'tasks',
      where: 'title LIKE ? OR details LIKE ?',
      whereArgs: ['%$q%', '%$q%'],
      orderBy: 'captured_at_utc DESC',
      limit: limit,
    );
    return rows.map(Task.fromRow).toList();
  }
}
