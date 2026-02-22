// Tempus Vista rebuild - generated 2026-02-21
// Local-first, Android-first.


import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class JsonlLogger {
  JsonlLogger._();
  static final JsonlLogger instance = JsonlLogger._();

  Future<File> _file(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final logsDir = Directory(p.join(dir.path, 'jsonl'));
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }
    return File(p.join(logsDir.path, name));
  }

  Future<void> append(String name, Map<String, Object?> obj) async {
    final f = await _file(name);
    final line = jsonEncode(obj);
    await f.writeAsString('$line\n', mode: FileMode.append, flush: true);
  }

  /// High-level event logger.
  /// Writes to jsonl/events.jsonl with a consistent envelope.
  Future<void> log(String eventType, Map<String, Object?> payload) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await append('events.jsonl', {
      'tsUtc': now,
      'event': eventType,
      'payload': payload,
    });
  }

}
