// Tempus Victa - Recycle Bin repository

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/app_db.dart';
import '../models/signal.dart';

class RecycleRepo {
  RecycleRepo._();
  static final RecycleRepo instance = RecycleRepo._();
  static const _uuid = Uuid();

  Future<void> moveToRecycle({required Signal signal, String reason = 'user_swipe'}) async {
    final d = await AppDb.instance.db;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await d.transaction((txn) async {
      await txn.update(
        'signals',
        {'status': 'recycle', 'modified_at_utc': now},
        where: 'id = ?',
        whereArgs: [signal.id],
      );
      await txn.insert(
        'recycle',
        {'id': _uuid.v4(), 'signal_id': signal.id, 'reason': reason, 'deleted_at_utc': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<List<Signal>> listRecycled({int limit = 200}) async {
    final d = await AppDb.instance.db;
    final rows = await d.query(
      'signals',
      where: 'status = ?',
      whereArgs: ['recycle'],
      orderBy: 'modified_at_utc DESC',
      limit: limit,
    );
    return rows.map((e) => Signal.fromRow(e)).toList();
  }

  Future<void> restoreToInbox(String signalId) async {
    final d = await AppDb.instance.db;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await d.update('signals', {'status': 'inbox', 'modified_at_utc': now}, where: 'id = ?', whereArgs: [signalId]);
  }

  Future<void> hardDelete(String signalId) async {
    final d = await AppDb.instance.db;
    await d.transaction((txn) async {
      await txn.delete('recycle', where: 'signal_id = ?', whereArgs: [signalId]);
      await txn.delete('signals', where: 'id = ?', whereArgs: [signalId]);
    });
  }
}
