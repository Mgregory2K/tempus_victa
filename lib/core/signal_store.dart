import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'signal_item.dart';

class SignalStore {
  static const String _kKey = 'tempus.signals.v1';

  static Future<List<SignalItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return <SignalItem>[];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(SignalItem.fromJson)
        .toList(growable: false);
  }

  static Future<void> save(List<SignalItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_kKey, encoded);
  }
}
