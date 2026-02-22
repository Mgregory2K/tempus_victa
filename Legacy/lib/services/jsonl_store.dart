import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

// This file reads and writes JSONL.
// JSONL = one JSON object per line.
// It is simple. It is boring. It is reliable.
class JsonlStore {
  Future<File> _file(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$name');
  }

  Future<List<Map<String, dynamic>>> readAll(String name) async {
    final f = await _file(name);
    if (!await f.exists()) return [];

    final lines = await f.readAsLines();
    final out = <Map<String, dynamic>>[];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final m = jsonDecode(line) as Map<String, dynamic>;
        out.add(m);
      } catch (_) {
        // If one line is bad, we skip it.
        // We do NOT crash.
      }
    }

    return out;
  }

  Future<void> append(String name, Map<String, dynamic> obj) async {
    final f = await _file(name);
    await f.parent.create(recursive: true);
    final line = jsonEncode(obj);
    await f.writeAsString('$line\n', mode: FileMode.append, flush: true);
  }

  Future<void> deleteIfExists(String name) async {
    final f = await _file(name);
    if (await f.exists()) {
      await f.delete();
    }
  }

  Future<File> getFile(String name) => _file(name);
}
