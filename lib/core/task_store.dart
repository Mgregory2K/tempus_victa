import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'task_item.dart';

class TaskStore {
  static const String _kKey = 'tempus.tasks.v1';

  static Future<List<TaskItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return <TaskItem>[];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <TaskItem>[];

    return decoded
        .whereType<Map>()
        .map((m) => TaskItem.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  static Future<void> save(List<TaskItem> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await prefs.setString(_kKey, raw);
  }

  static Future<void> upsert(TaskItem item) async {
    final tasks = await load();
    final idx = tasks.indexWhere((t) => t.id == item.id);
    if (idx >= 0) {
      tasks[idx] = item;
    } else {
      tasks.insert(0, item);
    }
    await save(tasks);
  }
}
