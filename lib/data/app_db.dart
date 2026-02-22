import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/signal.dart';
import '../models/task.dart';

class AppDb {
  static final AppDb instance = AppDb._init();
  static Database? _database;

  AppDb._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tempus_victa.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE signals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      content TEXT NOT NULL,
      source TEXT NOT NULL,
      created_at TEXT NOT NULL,
      is_recycled INTEGER NOT NULL
    )
    ''');

    await db.execute('''
    CREATE TABLE tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      description TEXT,
      completed INTEGER NOT NULL,
      recycled INTEGER NOT NULL,
      created_at TEXT NOT NULL
    )
    ''');
  }

  Future<int> insertSignal(SignalModel signal) async {
    final db = await instance.database;
    return await db.insert('signals', signal.toMap());
  }

  Future<int> insertTask(TaskModel task) async {
    final db = await instance.database;
    return await db.insert('tasks', task.toMap());
  }

  Future<List<SignalModel>> getSignals() async {
    final db = await instance.database;
    final result = await db.query('signals', orderBy: 'created_at DESC');
    return result.map((e) => SignalModel.fromMap(e)).toList();
  }

  Future<List<TaskModel>> getTasks() async {
    final db = await instance.database;
    final result = await db.query('tasks', orderBy: 'created_at DESC');
    return result.map((e) => TaskModel.fromMap(e)).toList();
  }
}
