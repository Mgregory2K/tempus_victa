import 'package:drift/drift.dart';
import 'package:mobile/data/db/app_db.dart';

class MissionsRepository {
  final AppDatabase _db;

  MissionsRepository(this._db);

  Stream<List<Mission>> watchMissions() {
    return (_db.select(_db.missions)
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<void> ensureInitialData() async {
    final count = await (_db.select(_db.missions)..limit(1)).getSingleOrNull();
    if (count == null) {
      await _db.into(_db.missions).insert(MissionsCompanion.insert(
            name: 'Build Skynet',
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
          ));
      await _db.into(_db.missions).insert(MissionsCompanion.insert(
            name: 'Achieve world peace',
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
          ));
    }
  }
}
