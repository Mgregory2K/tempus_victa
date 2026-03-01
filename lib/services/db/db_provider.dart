import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:path_provider/path_provider.dart';
import 'migration_runner.dart';
import '../lexicon/lexicon.dart';

class DatabaseProvider {
  static Database? _db;
  static String? _dbPath;

  /// Initialize the shared DB. If [dbPath] is null, uses application documents
  /// directory and creates `tempus_victa.sqlite` there. Pass ':memory:' to force
  /// in-memory DB (useful for tests).
  static Future<void> init({String? dbPath}) async {
    if (_db != null) return;
    String path = dbPath ?? '';
    if (path.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      path = '${dir.path}/tempus_victa.sqlite';
    }

    if (path == ':memory:') {
      _db = sqlite3.openInMemory();
      _dbPath = ':memory:';
    } else {
      final f = File(path);
      if (!f.existsSync()) {
        f.parent.createSync(recursive: true);
        f.createSync();
      }
      _db = sqlite3.open(path);
      _dbPath = path;
    }

    try {
      _db!.execute("PRAGMA journal_mode = WAL;");
      _db!.execute("PRAGMA busy_timeout = 10000;");
      _db!.execute("PRAGMA synchronous = NORMAL;");
      _db!.execute("PRAGMA temp_store = MEMORY;");
    } catch (_) {}

    // Run migrations using migration runner (reads PRAGMA user_version)
    MigrationRunner.applyMigrations(_db!);
  }

  static Database get instance {
    if (_db == null) throw StateError('DatabaseProvider not initialized');
    return _db!;
  }

  static String? get dbPath => _dbPath;

  static void dispose() {
    // Close any cached prepared statements in services that rely on the DB.
    try {
      LexiconService.close();
    } catch (_) {}
    _db?.dispose();
    _db = null;
    _dbPath = null;
  }
}
