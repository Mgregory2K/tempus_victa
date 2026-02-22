import 'package:drift/drift.dart';

class SignalTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get receivedAt => dateTime()();
  TextColumn get sourcePackage => text()();
  TextColumn get title => text().nullable()();
  TextColumn get body => text().nullable()();
  TextColumn get rawJson => text()();
  IntColumn get dayKey => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
