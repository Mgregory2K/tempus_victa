import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'signal_item.dart';
import 'task_item.dart';

class RecycleBinStore {
  static const String _kKeySignals = 'tempus.recycle.signals.v1';
  static const String _kKeyTasks = 'tempus.recycle.tasks.v1';

  static Future<List<SignalItem>> loadSignals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKeySignals);
    if (raw == null || raw.trim().isEmpty) return <SignalItem>[];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(SignalItem.fromJson)
        .toList(growable: false);
  }

  static Future<void> saveSignals(List<SignalItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_kKeySignals, encoded);
  }

  static Future<List<TaskItem>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKeyTasks);
    if (raw == null || raw.trim().isEmpty) return <TaskItem>[];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(TaskItem.fromJson)
        .toList(growable: false);
  }

  static Future<void> saveTasks(List<TaskItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_kKeyTasks, encoded);
  }
}
