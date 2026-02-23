import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SignalMuteStore {
  static const _kMutedPkgs = 'tempus.signal.mutedPkgs.v1';

  static Future<Set<String>> loadMutedPackages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kMutedPkgs);
    if (raw == null || raw.trim().isEmpty) return <String>{};
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <String>{};
    return decoded.map((e) => e.toString()).toSet();
  }

  static Future<void> saveMutedPackages(Set<String> pkgs) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(pkgs.toList()..sort());
    await prefs.setString(_kMutedPkgs, encoded);
  }

  static Future<void> toggleMutedPackage(String pkg, bool muted) async {
    final current = await loadMutedPackages();
    if (muted) {
      current.add(pkg);
    } else {
      current.remove(pkg);
    }
    await saveMutedPackages(current);
  }
}
