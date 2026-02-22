import 'package:drift/drift.dart';

class TrustScoreTable extends Table {
  TextColumn get entityKey => text()(); // e.g. 'domain:example.com' or 'person:spock'
  RealColumn get score => real().withDefault(const Constant(0.0))();
  IntColumn get evidenceCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get decayAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {entityKey};
}
