// Drift scaffold: provides an application-level database wrapper using Drift.
// NOTE: This file is a lightweight integration scaffold. To fully leverage Drift's
// typed tables and generators, run `flutter pub run build_runner build` after
// adding table definitions via `@DriftDatabase` and part files.

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Minimal runtime wrapper returning a Drift [QueryExecutor].
Future<QueryExecutor> openDriftDatabase({String? dbPath}) async {
  if (dbPath != null && dbPath == ':memory:') {
    return NativeDatabase.memory();
  }

  final dir = await getApplicationDocumentsDirectory();
  final file = File(dbPath ?? p.join(dir.path, 'tempus_victa.sqlite'));
  if (!file.existsSync()) file.createSync(recursive: true);
  return NativeDatabase(file);
}

// Example usage (scaffold):
// final executor = await openDriftDatabase();
// final db = MyDriftDatabase(executor); // requires generated `MyDriftDatabase`
