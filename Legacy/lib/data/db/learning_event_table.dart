import 'package:drift/drift.dart';

class LearningEventTable extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get kind => text()(); // 'ingest', 'route', 'user_action', etc.
  TextColumn get payloadJson => text()(); // append-only
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
