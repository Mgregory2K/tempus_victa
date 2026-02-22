import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor connect() {
  return LazyDatabase(() async {
    final storage = await DriftWebStorage.indexedDb('tempus_victa_db');
    return WebDatabase.withStorage(storage);
  });
}
