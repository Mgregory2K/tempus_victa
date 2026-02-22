import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:mobile/data/db/app_db.dart';

class CorkboardRepository {
  final AppDatabase _db;

  CorkboardRepository(this._db);

  Stream<List<CorkboardItem>> watchCorkboardItems() {
    return _db.select(_db.corkboardItems).watch();
  }

  Future<void> updateItemPosition(int id, Offset offset) {
    return (_db.update(_db.corkboardItems)..where((t) => t.id.equals(id))).write(
      CorkboardItemsCompanion(
        dx: Value(offset.dx),
        dy: Value(offset.dy),
        modifiedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> ensureInitialData() async {
    final count = await (_db.select(_db.corkboardItems)..limit(1)).getSingleOrNull();
    if (count == null) {
      await _db.into(_db.corkboardItems).insert(CorkboardItemsCompanion.insert(
            content: 'Idea for a new project...',
            color: 'yellow',
            dx: 50,
            dy: 100,
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
          ));
      await _db.into(_db.corkboardItems).insert(CorkboardItemsCompanion.insert(
            content: 'Remember to buy victory cigars!',
            color: 'pinkAccent',
            dx: 250,
            dy: 200,
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
          ));
    }
  }
}
