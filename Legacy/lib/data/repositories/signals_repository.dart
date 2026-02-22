import 'package:drift/drift.dart';
import 'package:mobile/data/db/app_db.dart';

class SignalsRepository {
  final AppDatabase _db;

  SignalsRepository(this._db);

  Stream<List<Signal>> watchSignals() {
    return (_db.select(_db.signals)
          ..orderBy([
            (t) => OrderingTerm(expression: t.receivedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<void> deleteSignal(int id) {
    return (_db.delete(_db.signals)..where((t) => t.id.equals(id))).go();
  }

  /// Insert a new signal (canonical ingestion item).
  /// All timestamps are written here (DB-level), not trusted from UI.
  Future<int> insertSignal({
    required String content,
    required String source,
    DateTime? receivedAt,
  }) {
    final now = DateTime.now();
    return _db.into(_db.signals).insert(SignalsCompanion.insert(
          content: content,
          source: source,
          receivedAt: receivedAt ?? now,
          createdAt: now,
          modifiedAt: now,
        ));
  }

  Future<void> ensureInitialData() async {
    final any = await (_db.select(_db.signals)..limit(1)).getSingleOrNull();
    if (any == null) {
      for (var i = 0; i < 5; i++) {
        await insertSignal(
          content: 'Signal Content ${i + 1}: This is a preview from the real database...',
          source: 'Source ${i + 1}',
        );
      }
    }
  }
