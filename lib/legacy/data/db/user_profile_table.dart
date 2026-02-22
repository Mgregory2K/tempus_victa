import 'package:drift/drift.dart';

class UserProfileTable extends Table {
  TextColumn get id => text()(); // uuid
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get traitsJson => text()(); // append-only snapshots
  TextColumn get source => text().nullable()(); // 'seed', 'heartbeat', etc.

  @override
  Set<Column> get primaryKey => {id};
}
