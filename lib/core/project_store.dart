import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'project_item.dart';
import 'task_store.dart';

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



  /// ZIP 4 — compute completion ratio for a project based on tasks.
  /// Returns 0.0 when there are no tasks assigned to the project.
  static Future<double> completionRatio(String projectId) async {
    final tasks = await TaskStore.load();
    final scoped = tasks.where((t) => t.projectId == projectId).toList();
    if (scoped.isEmpty) return 0.0;
    final done = scoped.where((t) => t.isCompleted).length;
    return done / scoped.length;
  }

  /// ZIP 4 — Mark project completion explicitly (used after auto-rule).
  static Future<void> setCompleted(String projectId, bool completed) async {
    final items = await load();
    final idx = items.indexWhere((p) => p.id == projectId);
    if (idx < 0) return;

    final now = DateTime.now();
    final p = items[idx];
    final updated = p.copyWith(
      isCompleted: completed,
      completedAt: completed ? now : null,
    );

    final next = List<ProjectItem>.of(items);
    next[idx] = updated;
    await save(next);
  }

  /// ZIP 4 — Rule: all tasks complete => project complete.
  /// - If there are zero tasks in the project, project is NOT auto-completed.
  /// - If project is already complete and tasks get added later, it will remain complete unless explicitly reopened.
  static Future<void> refreshCompletionFromTasks(String projectId) async {
    final items = await load();
    final idx = items.indexWhere((p) => p.id == projectId);
    if (idx < 0) return;

    final tasks = await TaskStore.load();
    final scoped = tasks.where((t) => t.projectId == projectId).toList();
    if (scoped.isEmpty) return;

    final allDone = scoped.every((t) => t.isCompleted);
    final anyOpen = scoped.any((t) => !t.isCompleted);

    final p = items[idx];
    final now = DateTime.now();

    // If all tasks complete => project complete.
    if (allDone && !p.isCompleted) {
      final next = List<ProjectItem>.of(items);
      next[idx] = p.copyWith(isCompleted: true, completedAt: now);
      await save(next);
      return;
    }

    // If project is complete but an open task exists (e.g., task attached later) => reopen.
    if (p.isCompleted && anyOpen) {
      final next = List<ProjectItem>.of(items);
      next[idx] = p.copyWith(isCompleted: false, completedAt: null);
      await save(next);
    }
  }

  static Future<ProjectItem> addProject(String name) async {
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    final p = ProjectItem(id: id, createdAt: now, name: name.trim());
    final items = await load();
    await save([p, ...items]);
    return p;
  }
}
