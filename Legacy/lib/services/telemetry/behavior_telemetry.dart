import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BehaviorTelemetry {
  static const _fileName = 'telemetry.jsonl';

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  static Future<void> log(String event, Map<String, dynamic> props) async {
    try {
      final f = await _file();
      await f.create(recursive: true);

      final payload = <String, dynamic>{
        'at': DateTime.now().toUtc().toIso8601String(),
        'event': event,
        'props': props,
      };

      await f.writeAsString('${jsonEncode(payload)}\n', mode: FileMode.append, flush: true);
    } catch (_) {
      // Telemetry must NEVER crash UX.
    }
  }
}
