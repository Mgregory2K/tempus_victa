// Tempus Victa - Signal repository (sqflite)

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/app_db.dart';
import '../models/signal.dart';

class SignalRepo {
  SignalRepo._();
  static final SignalRepo instance = SignalRepo._();
  static const _uuid = Uuid();

  Future<List<Signal>> list({String status = 'inbox'}) async {
    final d = await AppDb.instance.db;
    final rows = await d.query(
      'signals',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'captured_at_utc DESC',
    );
    return rows.map((e) => Signal.fromRow(e)).toList();
  }

  Future<List<Signal>> listAll({int limit = 200}) async {
    final d = await AppDb.instance.db;
    final rows = await d.query('signals', orderBy: 'captured_at_utc DESC', limit: limit);
    return rows.map((e) => Signal.fromRow(e)).toList();
  }

  Future<Signal> create({
    required String kind,
    required String source,
    String? text,
    String? transcript,
    String status = 'inbox',
    double confidence = 0,
    double weight = 0,
    DateTime? capturedAtUtc,
  }) async {
    final d = await AppDb.instance.db;
    final now = DateTime.now().toUtc();
    final cap = capturedAtUtc ?? now;

    final signal = Signal(
      id: _uuid.v4(),
      kind: kind,
      source: source,
      status: status,
      confidence: confidence,
      weight: weight,
      capturedAtUtc: cap,
      createdAtUtc: now,
      modifiedAtUtc: now,
      text: text,
      transcript: transcript,
    );

    await d.insert('signals', signal.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    return signal;
  }

  Future<void> updateStatus(String id, String status, {double? confidence}) async {
    final d = await AppDb.instance.db;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await d.update(
      'signals',
      {
        'status': status,
        if (confidence != null) 'confidence': confidence,
        'modified_at_utc': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(String id) async {
    final d = await AppDb.instance.db;
    await d.delete('signals', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setWeight(String id, double weight) async {
    final d = await AppDb.instance.db;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await d.update('signals', {'weight': weight, 'modified_at_utc': now}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Signal>> search(String query, {int limit = 10}) async {
    final q = query.trim();
    if (q.isEmpty) return const <Signal>[];
    final d = await AppDb.instance.db;
    final rows = await d.query(
      'signals',
      where: 'text LIKE ? OR transcript LIKE ? OR source LIKE ?',
      whereArgs: ['%$q%', '%$q%', '%$q%'],
      orderBy: 'captured_at_utc DESC',
      limit: limit,
    );
    return rows.map((e) => Signal.fromRow(e)).toList();
  }
}
