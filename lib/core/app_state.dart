import 'package:flutter/material.dart';
import '../data/app_db.dart';
import '../models/signal.dart';
import '../models/task.dart';
import 'event_bus.dart';

class AppState extends ChangeNotifier {
  final AppDb _db = AppDb.instance;
  final EventBus _bus = EventBus();

  List<SignalModel> signals = [];
  List<TaskModel> tasks = [];

  AppState() {
    _bus.stream.listen((_) {
      refresh();
    });
  }

  Future<void> init() async {
    await refresh();
  }

  Future<void> refresh() async {
    signals = await _db.getSignals();
    tasks = await _db.getTasks();
    notifyListeners();
  }

  Future<void> addSignal(String content, String source) async {
    final signal = SignalModel(
      content: content,
      source: source,
      createdAt: DateTime.now(),
    );
    await _db.insertSignal(signal);
    _bus.emit("refresh");
  }

  Future<void> addTask(String title) async {
    final task = TaskModel(
      title: title,
      createdAt: DateTime.now(),
    );
    await _db.insertTask(task);
    _bus.emit("refresh");
  }
}
