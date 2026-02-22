// lib/data/db/trusted_sources_active_table.dart
import 'package:drift/drift.dart';

class TrustedSourcesActiveTable extends Table {
  TextColumn get domain => text()();

  /// 0.0 - 1.0 base trust score (seeded)
  RealColumn get baseTrust => real().withDefault(const Constant(0.55))();

  /// 0.0 - 1.0 likelihood of ideological slant / agenda
  RealColumn get biasRisk => real().withDefault(const Constant(0.25))();

  /// short category label ("vendor", "standards", "encyclopedia", ...)
  TextColumn get category => text().withDefault(const Constant(''))();

  /// reinforcement from user behavior (clicks / actions)
  RealColumn get reinforcement => real().withDefault(const Constant(0.0))();

  IntColumn get usageCount => integer().withDefault(const Constant(0))();

  /// epoch millis UTC
  IntColumn get lastUsedAt => integer().nullable()();

  /// epoch millis UTC
  IntColumn get insertedAt => integer()();

  /// Small decay tracker used for pruning.
  RealColumn get decay => real().withDefault(const Constant(0.0))();

  /// Rough bytes estimate for cap enforcement.
  IntColumn get bytesEstimate => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {domain};
}
