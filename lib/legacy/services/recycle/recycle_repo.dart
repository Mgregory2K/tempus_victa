import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class RecycleRepo {
  static const _file = 'recycle_bin.jsonl';

  static Future<File> _path() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_file');
  }

  static Future<void> addRawJson(Map<String, dynamic> raw) async {
    final f = await _path();
    await f.writeAsString('${jsonEncode(raw)}\n', mode: FileMode.append, flush: true);
  }

  static Future<List<Map<String, dynamic>>> readAll({int limit = 500}) async {
    final f = await _path();
    if (!await f.exists()) return [];
    final lines = await f.readAsLines();
    final out = <Map<String, dynamic>>[];
    for (final l in lines.reversed) {
      if (l.trim().isEmpty) continue;
      try {
        out.add(jsonDecode(l) as Map<String, dynamic>);
      } catch (_) {}
      if (out.length >= limit) break;
    }
    return out;
  }

  static Future<void> clear() async {
    final f = await _path();
    if (await f.exists()) await f.writeAsString('', flush: true);
  }
}
