import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'task_item.dart';
import 'unified_index_service.dart';

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

    // ZIP 11 — keep tasks globally searchable with provenance metadata.
    final meta = <String, dynamic>{
      if (item.decisionId != null) 'decisionId': item.decisionId,
      if (item.projectId != null) 'projectId': item.projectId,
      'isCompleted': item.isCompleted,
    };

    await UnifiedIndexService.upsert(
      id: item.id,
      type: 'task',
      title: item.title,
      body: item.transcript ?? '',
      meta: meta,
    );
  }

  /// ZIP 11 — delete a task and remove it from the global index.
  static Future<void> remove(String id) async {
    final tasks = await load();
    tasks.removeWhere((t) => t.id == id);
    await save(tasks);
    await UnifiedIndexService.remove(id);
  }
}
