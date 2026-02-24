import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'twin_event.dart';

class TwinEventLedger {
  final File _file;

  TwinEventLedger._(this._file);

  static Future<TwinEventLedger> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final tp = Directory(p.join(dir.path, 'twin_plus'));
    if (!tp.existsSync()) tp.createSync(recursive: true);
    final f = File(p.join(tp.path, 'events.jsonl'));
    if (!f.existsSync()) f.createSync(recursive: true);
    return TwinEventLedger._(f);
  }

  Future<void> append(TwinEvent e) async {
    final line = jsonEncode(e.toJson());
    await _file.writeAsString('$line\n', mode: FileMode.append, flush: true);
  }

  /// Lightweight query: reads the whole file. Fine for day-one volumes.
  /// Later we can migrate to Drift without changing callers.
  List<TwinEvent> query({int limit = 50}) {
    try {
      final lines = _file.readAsLinesSync();
      final out = <TwinEvent>[];
      for (int i = lines.length - 1; i >= 0 && out.length < limit; i--) {
        final s = lines[i].trim();
        if (s.isEmpty) continue;
        final j = jsonDecode(s);
        if (j is Map<String, dynamic>) out.add(TwinEvent.fromJson(j));
      }
      return out.reversed.toList(growable: false);
    } catch (_) {
      return const <TwinEvent>[];
    }
  }
}
