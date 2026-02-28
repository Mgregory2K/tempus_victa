import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'signal_item.dart';
import 'task_item.dart';

class RecycleBinStore {
  static const String _kKeySignals = 'tempus.recycle.signals.v1';
  static const String _kKeyTasks = 'tempus.recycle.tasks.v1';
  static const String _kKeyCork = 'tempus.recycle.cork.v1';

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

  // ZIP 5 — Corkboard recycle support (for transforms + provenance)
  static Future<List<Map<String, dynamic>>> loadCorkNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKeyCork);
    if (raw == null || raw.trim().isEmpty) return <Map<String, dynamic>>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <Map<String, dynamic>>[];
    return decoded.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  static Future<void> saveCorkNotes(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKeyCork, jsonEncode(items));
  }

  static Future<void> addCorkNote({
    required String id,
    required String text,
    required int createdAtEpochMs,
    String? sourceId,
  }) async {
    final items = await loadCorkNotes();
    items.insert(0, {
      'id': id,
      'text': text,
      'createdAtEpochMs': createdAtEpochMs,
      if (sourceId != null) 'sourceId': sourceId,
    });
    await saveCorkNotes(items);
  }

}
