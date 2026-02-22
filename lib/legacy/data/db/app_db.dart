import 'package:drift/drift.dart';

import 'connection/connection.dart' as impl;

import 'signal_table.dart';
import 'time_savings_table.dart';

part 'app_db.g.dart';

/// Canonical local-first database (Phase 0/1).
///
/// Drift codegen is embedded (app_db.g.dart) to keep builds reproducible
/// without requiring build_runner on every machine.
class AppDb extends _$AppDb {
  AppDb() : super(impl.connect());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Deterministic recovery strategy (Phase 0/1): drop and recreate.
          for (final t in allTables) {
            try {
              await m.drop(t);
            } catch (_) {}
          }
          await m.createAll();
        await customStatement('CREATE TABLE IF NOT EXISTS meta (k TEXT PRIMARY KEY, v TEXT, updated_at INTEGER)');
        },
      );

  // -------------------------
  // Signals (Signal Bay)
  // -------------------------

  Stream<List<SignalTableData>> watchLatestSignals({int limit = 250}) {
    return (select(signalTable)
          ..orderBy([(t) => OrderingTerm.desc(t.receivedAt)])
          ..limit(limit))
        .watch();
  }

  Future<void> deleteSignal(String id) async {
    await (delete(signalTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> upsertSignal({
    required String id,
    required DateTime receivedAt,
    required String sourcePackage,
    String? title,
    String? body,
    required String rawJson,
    required int dayKey,
  }) async {
    await into(signalTable).insert(
      SignalTableCompanion(
        id: Value(id),
        receivedAt: Value(receivedAt),
        sourcePackage: Value(sourcePackage),
        title: Value(title),
        body: Value(body),
        rawJson: Value(rawJson),
        dayKey: Value(dayKey),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<bool> hasDuplicateInLast24h({
    required DateTime receivedAt,
    required String sourcePackage,
    String? title,
    String? body,
  }) async {
    final since = receivedAt.subtract(const Duration(hours: 24));

    final q = select(signalTable)
      ..where((t) => t.receivedAt.isBiggerOrEqualValue(since))
      ..where((t) => t.sourcePackage.equals(sourcePackage));

    if (title == null || title.trim().isEmpty) {
      q.where((t) => t.title.isNull());
    } else {
      q.where((t) => t.title.equals(title));
    }

    if (body == null || body.trim().isEmpty) {
      q.where((t) => t.body.isNull());
    } else {
      q.where((t) => t.body.equals(body));
    }

    final row = await (q..limit(1)).getSingleOrNull();
    return row != null;
  }

  // -------------------------
  // Time Saved Ledger
  // -------------------------

  Stream<int> watchTimeSavedSeconds() {
    final sumExpr = timeSavingsTable.secondsSaved.sum();
    final q = selectOnly(timeSavingsTable)..addColumns([sumExpr]);
    return q.watch().map((rows) {
      final row = rows.isNotEmpty ? rows.first : null;
      final v = row?.read(sumExpr);
      return (v ?? 0) as int;
    });
  }


  // --- Simple KV meta store (settings + per-item status) ---
  Future<String?> getMeta(String key) async {
    final row = await customSelect(
      'SELECT v FROM meta WHERE k = ? LIMIT 1',
      variables: [Variable<String>(key)],
    ).getSingleOrNull();
    return row == null ? null : row.read<String>('v');
  }

  Future<void> setMeta(String key, String value) async {
    await customStatement(
      'INSERT OR REPLACE INTO meta (k, v, updated_at) VALUES (?, ?, ?)',
      [key, value, DateTime.now().toUtc().millisecondsSinceEpoch],
    );
  }

  Future<void> deleteMeta(String key) async {
    await customStatement('DELETE FROM meta WHERE k = ?', [key]);
  }

}
