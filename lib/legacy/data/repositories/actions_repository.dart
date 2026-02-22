import 'package:drift/drift.dart';
import 'package:mobile/data/db/app_db.dart';

class ActionsRepository {
  final AppDatabase _db;

  ActionsRepository(this._db);

  Stream<List<Action>> watchTodaysActions() {
    return (_db.select(_db.actions)
          ..where((t) => t.isCompleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<void> createActionFromSignal(Signal signal) {
    final now = DateTime.now();
    return _db.into(_db.actions).insert(ActionsCompanion.insert(
          title: signal.content,
          createdAt: now,
          modifiedAt: now,
        ));
  }

  /// Canonical: create an action directly from captured text.
  Future<void> createActionFromText(String text, {int? missionId, DateTime? dueDate}) {
    final now = DateTime.now();
    final title = text.trim().isEmpty ? 'New task' : text.trim();
    return _db.into(_db.actions).insert(ActionsCompanion.insert(
          title: title,
          createdAt: now,
          modifiedAt: now,
          dueDate: Value(dueDate),
          missionId: Value(missionId),
        ));
  }

  Future<void> updateAction(ActionsCompanion action) {
    return (_db.update(_db.actions)..where((t) => t.id.equals(action.id.value))).write(action);
  }

  Future<void> setCompleted(int id, bool done) {
    return updateAction(
      ActionsCompanion(
        id: Value(id),
        isCompleted: Value(done),
        modifiedAt: Value(DateTime.now()),
      ),
    );
  }
}
