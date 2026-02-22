import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LayoutRepo {
  final String fileName;

  LayoutRepo(this.fileName);

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, fileName));
  }

  Future<Map<String, Offset>> loadPositions() async {
    final f = await _file();
    if (!await f.exists()) return {};

    try {
      final raw = await f.readAsString();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final out = <String, Offset>{};
      for (final e in map.entries) {
        final v = e.value;
        if (v is Map<String, dynamic>) {
          final dx = (v['dx'] as num?)?.toDouble();
          final dy = (v['dy'] as num?)?.toDouble();
          if (dx != null && dy != null) out[e.key] = Offset(dx, dy);
        }
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> savePositions(Map<String, Offset> positions) async {
    final f = await _file();
    await f.parent.create(recursive: true);

    final out = <String, dynamic>{};
    for (final e in positions.entries) {
      out[e.key] = {'dx': e.value.dx, 'dy': e.value.dy};
    }
    await f.writeAsString(jsonEncode(out), mode: FileMode.write, flush: true);
  }
}
