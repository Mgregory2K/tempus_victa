import 'package:drift/drift.dart';

class RoutingTraceTable extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get input => text()();
  TextColumn get output => text()();
  TextColumn get stepsJson => text()(); // ordered steps + decisions
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
