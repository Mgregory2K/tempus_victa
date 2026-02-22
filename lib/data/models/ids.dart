// Tempus Victa - ID helper (simple, deterministic enough for local-first)

import 'dart:math';

class Ids {
  static final _rand = Random();

  static String newId() {
    final ts = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
    final r = _rand.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '${ts}_$r';
  }
}
