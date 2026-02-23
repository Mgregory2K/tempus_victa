import 'dart:math';

import 'package:uuid/uuid.dart';

import '../data/db/corkboard_db.dart';

class CorkNoteModel {
  final String id;
  final String text;
  final double x;
  final double y;
  final int z;
  final int colorIndex;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;

  const CorkNoteModel({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    required this.z,
    required this.colorIndex,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
  });
}

class CorkboardStore {
  static const _uuid = Uuid();

  static Future<void> addText(
    String text, {
    double? x,
    double? y,
    int? colorIndex,
  }) async {
    final db = await CorkboardDb.instance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final nextZ = await _maxZ(db) + 1;

    // Slight randomization so new notes don't perfectly overlap.
    final r = Random();
    final dx = (r.nextDouble() * 18) - 9;
    final dy = (r.nextDouble() * 18) - 9;

    db.execute(
      'INSERT OR REPLACE INTO cork_notes (id, text, x, y, z, color_index, created_at_ms, updated_at_ms) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        _uuid.v4(),
        text,
        (x ?? 28) + dx,
        (y ?? 90) + dy,
        nextZ,
        colorIndex ?? r.nextInt(8),
        now,
        now,
      ],
    );
  }

  static Future<List<CorkNoteModel>> list() async {
    final db = await CorkboardDb.instance();
    final rs = db.select('SELECT id, text, x, y, z, color_index, created_at_ms, updated_at_ms FROM cork_notes ORDER BY z ASC');
    return rs
        .map(
          (r) => CorkNoteModel(
            id: r['id'] as String,
            text: r['text'] as String,
            x: (r['x'] as num).toDouble(),
            y: (r['y'] as num).toDouble(),
            z: (r['z'] as int),
            colorIndex: (r['color_index'] as int),
            createdAtEpochMs: (r['created_at_ms'] as int),
            updatedAtEpochMs: (r['updated_at_ms'] as int),
          ),
        )
        .toList(growable: false);
  }

  static Future<void> updateText(String id, String newText) async {
    final db = await CorkboardDb.instance();
    final now = DateTime.now().millisecondsSinceEpoch;
    db.execute('UPDATE cork_notes SET text = ?, updated_at_ms = ? WHERE id = ?', [newText, now, id]);
  }

  static Future<void> updatePosition(String id, double x, double y) async {
    final db = await CorkboardDb.instance();
    final now = DateTime.now().millisecondsSinceEpoch;
    db.execute('UPDATE cork_notes SET x = ?, y = ?, updated_at_ms = ? WHERE id = ?', [x, y, now, id]);
  }

  static Future<void> bringToFront(String id) async {
    final db = await CorkboardDb.instance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final nextZ = await _maxZ(db) + 1;
    db.execute('UPDATE cork_notes SET z = ?, updated_at_ms = ? WHERE id = ?', [nextZ, now, id]);
  }

  static Future<void> delete(String id) async {
    final db = await CorkboardDb.instance();
    db.execute('DELETE FROM cork_notes WHERE id = ?', [id]);
  }

  static Future<int> _maxZ(db) async {
    final rs = db.select('SELECT MAX(z) AS mz FROM cork_notes');
    if (rs.isEmpty) return 0;
    final v = rs.first['mz'];
    if (v == null) return 0;
    return (v as int);
  }
}
