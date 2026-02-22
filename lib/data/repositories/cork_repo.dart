// Tempus Vista rebuild - generated 2026-02-21
// Local-first, Android-first.


import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/app_db.dart';

class CorkRepo {
  CorkRepo._();
  static final CorkRepo instance = CorkRepo._();
  static const _uuid = Uuid();

  Future<List<Map<String, Object?>>> list() async {
    final d = await AppDb.instance.db;
    return d.query('cork_notes', orderBy: 'created_at_utc DESC', limit: 500);
  }

  Future<void> add(String text) async {
    final d = await AppDb.instance.db;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await d.insert(
      'cork_notes',
      {'id': _uuid.v4(), 'text': text, 'created_at_utc': now, 'modified_at_utc': now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final d = await AppDb.instance.db;
    await d.delete('cork_notes', where: 'id = ?', whereArgs: [id]);
  }
}
