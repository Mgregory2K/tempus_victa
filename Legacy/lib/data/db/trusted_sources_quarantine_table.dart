// lib/data/db/trusted_sources_quarantine_table.dart
import 'package:drift/drift.dart';

class TrustedSourcesQuarantineTable extends Table {
  TextColumn get domain => text()();

  /// why it was quarantined (porn_keyword, onion, illegal_keyword, cap_overflow, ...)
  TextColumn get reason => text().withDefault(const Constant(''))();

  RealColumn get originalTrust => real().withDefault(const Constant(0.0))();
  RealColumn get originalBiasRisk => real().withDefault(const Constant(0.0))();
  TextColumn get originalCategory => text().withDefault(const Constant(''))();

  /// epoch millis UTC
  IntColumn get insertedAt => integer()();

  /// Rough bytes estimate for cap enforcement.
  IntColumn get bytesEstimate => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {domain};
}
