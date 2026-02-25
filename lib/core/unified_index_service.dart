import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight global index for Tempus.
/// Local-first. No AI dependency.
/// Entities add/update/remove their own entries.
class UnifiedIndexService {
  static const _kIndex = 'unified.index.v1';

  static Future<List<Map<String, dynamic>>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kIndex);
    if (raw == null || raw.trim().isEmpty) return <Map<String, dynamic>>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <Map<String, dynamic>>[];
    return decoded.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: true);
  }

  static Future<void> _saveAll(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kIndex, jsonEncode(list));
  }

  static Future<void> upsert({
    required String id,
    required String type,
    required String title,
    String body = '',
    Map<String, dynamic> meta = const {},
  }) async {
    final list = await _loadAll();
    list.removeWhere((e) => e['id'] == id);
    list.add({
      'id': id,
      'type': type,
      'title': title,
      'body': body,
      'meta': meta,
    });
    await _saveAll(list);
  }

  // Back-compat alias (older callers used addEntry).
  static Future<void> addEntry({
    required String id,
    required String type,
    required String title,
    String? body,
    Map<String, dynamic>? meta,
  }) async {
    await upsert(
      id: id,
      type: type,
      title: title,
      body: body ?? '',
      meta: meta ?? const {},
    );
  }


  static Future<void> remove(String id) async {
    final list = await _loadAll();
    list.removeWhere((e) => e['id'] == id);
    await _saveAll(list);
  }

  static Future<List<Map<String, dynamic>>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return <Map<String, dynamic>>[];
    final list = await _loadAll();
    return list.where((e) {
      final title = (e['title'] ?? '').toString().toLowerCase();
      final body = (e['body'] ?? '').toString().toLowerCase();
      return title.contains(q) || body.contains(q);
    }).toList(growable: false);
  }
}
