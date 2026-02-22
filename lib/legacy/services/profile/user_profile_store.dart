import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class UserProfileStore {
  static const _fileName = 'user_profile.json';

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  static Future<void> ensureSeeded() async {
    final f = await _file();
    if (await f.exists()) return;

    final seed = {
      'version': 1,
      'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
      'updatedAtUtc': DateTime.now().toUtc().toIso8601String(),

      // Trust anchors (you can edit later; this is just the initial seed)
      'trustedPeople': {
        // stored by identifier (phone/email later). For now: names.
        'Jen': {'trust': 0.98, 'confidence': 0.90},
        'Dylan': {'trust': 0.95, 'confidence': 0.85},
        'Liam': {'trust': 0.95, 'confidence': 0.85},
        'Adam Schneider': {'trust': 0.95, 'confidence': 0.85},
      },

      // Domain trust seeds (local learning will evolve these)
      'trustedDomains': {
        'wikipedia.org': 0.65,
        'microsoft.com': 0.85,
        'cisco.com': 0.85,
        'reddit.com': 0.40,
      },

      // Learning signals (attention/action) – values grow over time
      'attention': {
        'dailyBrief': {'opens': 0, 'dwellMs': 0},
        'readyRoom': {'opens': 0, 'sends': 0},
      },

      // Overrides remembered (user corrections go here)
      'overrides': {
        'patterns': [],
        'domains': [],
        'people': [],
      }
    };

    await f.create(recursive: true);
    await f.writeAsString(jsonEncode(seed), flush: true);
  }

  static Future<Map<String, dynamic>> read() async {
    final f = await _file();
    if (!await f.exists()) {
      await ensureSeeded();
    }
    final text = await f.readAsString();
    return (jsonDecode(text) as Map).cast<String, dynamic>();
  }

  static Future<void> write(Map<String, dynamic> data) async {
    final f = await _file();
    data['updatedAtUtc'] = DateTime.now().toUtc().toIso8601String();
    await f.create(recursive: true);
    await f.writeAsString(jsonEncode(data), flush: true);
  }
}
