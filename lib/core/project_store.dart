import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'project_item.dart';

class ProjectStore {
  static const String _kKey = 'tempus.projects.v1';

  static Future<List<ProjectItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return <ProjectItem>[];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ProjectItem.fromJson)
        .toList(growable: false);
  }

  static Future<void> save(List<ProjectItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_kKey, encoded);
  }
}
