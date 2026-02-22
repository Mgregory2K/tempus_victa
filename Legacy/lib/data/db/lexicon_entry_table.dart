import 'package:drift/drift.dart';

class LexiconEntryTable extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get trigger => text()(); // substring / keyword (v1)
  TextColumn get meaning => text().nullable()(); // human readable
  TextColumn get action => text().nullable()(); // action hint (v1)
  RealColumn get confidence => real().withDefault(const Constant(0.5))();
  TextColumn get provenance => text().nullable()(); // where learned
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
