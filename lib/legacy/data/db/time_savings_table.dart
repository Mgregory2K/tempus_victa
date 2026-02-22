import 'package:drift/drift.dart';

class TimeSavingsTable extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get category => text()(); // 'automation', 'dedupe', 'accepted_suggestion'
  IntColumn get secondsSaved => integer()(); // always >= 0
  RealColumn get confidence => real().withDefault(const Constant(0.5))();
  TextColumn get traceId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
