import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class CorkboardDb {
  CorkboardDb._();

  static Database? _db;

  static Future<Database> instance() async {
    if (_db != null) return _db!;

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/tempus_victa.sqlite');

    final db = sqlite3.open(file.path);
    db.execute('''
      CREATE TABLE IF NOT EXISTS cork_notes (
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        x REAL NOT NULL DEFAULT 24,
        y REAL NOT NULL DEFAULT 24,
        z INTEGER NOT NULL DEFAULT 0,
        color_index INTEGER NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      );
    ''');

    _db = db;
    return db;
  }

  static Future<void> close() async {
    _db?.dispose();
    _db = null;
  }
}
