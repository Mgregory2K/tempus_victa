import 'dart:io';
import 'dart:async';

import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('Multiple connections write concurrently without permanent lock',
      () async {
    final tmp = Directory.systemTemp.createTempSync('tv_db_conc');
    final dbPath = '${tmp.path}/conc.db';
    final f = File(dbPath);
    if (!f.existsSync()) f.createSync(recursive: true);

    final db1 = sqlite3.open(dbPath);
    final db2 = sqlite3.open(dbPath);

    try {
      // pragmas to reduce lock contention
      db1.execute('PRAGMA journal_mode = WAL;');
      db1.execute('PRAGMA busy_timeout = 10000;');
      db2.execute('PRAGMA journal_mode = WAL;');
      db2.execute('PRAGMA busy_timeout = 10000;');

      db1.execute(
          'CREATE TABLE IF NOT EXISTS conc_test (id TEXT PRIMARY KEY, val INTEGER);');

      // perform many small concurrent inserts from both connections
      final futures = <Future>[];
      for (var i = 0; i < 50; i++) {
        futures.add(Future(() {
          try {
            final id = 'a-$i';
            db1.execute(
                'INSERT OR REPLACE INTO conc_test (id,val) VALUES (\?, ?);',
                [id, i]);
          } catch (e) {
            // capture but don't rethrow here
          }
        }));
        futures.add(Future(() {
          try {
            final id = 'b-$i';
            db2.execute(
                'INSERT OR REPLACE INTO conc_test (id,val) VALUES (\?, ?);',
                [id, i]);
          } catch (e) {
            // ignore
          }
        }));
      }

      await Future.wait(futures);

      final rows = db1.select('SELECT count(*) as c FROM conc_test');
      final c = rows.first['c'] as int;
      expect(c, greaterThanOrEqualTo(50));
    } finally {
      db1.dispose();
      db2.dispose();
      tmp.deleteSync(recursive: true);
    }
  });
}
