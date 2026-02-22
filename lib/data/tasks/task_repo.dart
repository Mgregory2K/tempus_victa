import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'task_model.dart';

class TaskRepo {
  static const String _fileName = 'tasks_v1.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<TaskModel>> loadAll() async {
    final f = await _file();
    if (!await f.exists()) return [];
    final raw = await f.readAsString();
    if (raw.trim().isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(TaskModel.fromJson).toList()
      ..sort((a, b) => b.createdAtEpochMs.compareTo(a.createdAtEpochMs));
  }

  Future<void> saveAll(List<TaskModel> tasks) async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(tasks.map((t) => t.toJson()).toList()));
    await tmp.rename(f.path);
  }
}
