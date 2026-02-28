import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight global index for Tempus (local-first).
///
/// ZIP 14 — Hardening:
/// - Adds updatedAtMs timestamp
/// - De-dupes by (id,type)
/// - Caps total entries to prevent unbounded prefs growth
/// - Search scoring + recency ordering
class UnifiedIndexService {
  static const _kIndex = 'unified.index.v1';

  /// Guardrail to keep SharedPreferences from bloating over time.
  /// (This is a local-first mobile app; indexes must stay lean.)
  static const int _maxEntries = 5000;

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

  static int _updatedAt(Map<String, dynamic> e) {
    final v = e['updatedAtMs'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static Future<void> _capSize(List<Map<String, dynamic>> list) async {
    if (list.length <= _maxEntries) return;

    // Drop oldest first by updatedAtMs; if missing, treat as oldest.
    list.sort((a, b) => _updatedAt(a).compareTo(_updatedAt(b)));

    final overflow = list.length - _maxEntries;
    if (overflow > 0) {
      list.removeRange(0, overflow);
    }
  }

  static Future<void> upsert({
    required String id,
    required String type,
    required String title,
    String body = '',
    Map<String, dynamic> meta = const {},
  }) async {
    final list = await _loadAll();

    // De-dupe by (id,type). Older versions only de-duped by id.
    list.removeWhere((e) => (e['id'] == id) && (e['type'] == type));

    final now = DateTime.now().millisecondsSinceEpoch;
    list.add({
      'id': id,
      'type': type,
      'title': title,
      'body': body,
      'meta': meta,
      'updatedAtMs': now,
    });

    await _capSize(list);
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

  static int _score(String q, String title, String body) {
    // Simple, deterministic scoring (no AI).
    // Higher is better.
    int s = 0;

    if (title == q) s += 500;
    if (title.startsWith(q)) s += 250;
    if (title.contains(q)) s += 120;

    if (body == q) s += 180;
    if (body.startsWith(q)) s += 90;
    if (body.contains(q)) s += 40;

    return s;
  }

  static Future<List<Map<String, dynamic>>> search(String query, {int limit = 50}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return <Map<String, dynamic>>[];

    final list = await _loadAll();

    final scored = <Map<String, dynamic>>[];

    for (final e in list) {
      final title = (e['title'] ?? '').toString().toLowerCase();
      final body = (e['body'] ?? '').toString().toLowerCase();

      if (!(title.contains(q) || body.contains(q))) continue;

      final score = _score(q, title, body);
      scored.add({
        ...e,
        '_score': score,
      });
    }

    // Sort: score desc, then updatedAtMs desc
    scored.sort((a, b) {
      final sa = (a['_score'] is int) ? (a['_score'] as int) : int.tryParse('${a['_score']}') ?? 0;
      final sb = (b['_score'] is int) ? (b['_score'] as int) : int.tryParse('${b['_score']}') ?? 0;
      if (sb != sa) return sb.compareTo(sa);
      return _updatedAt(b).compareTo(_updatedAt(a));
    });

    final out = scored.take(limit).map((e) {
      e.remove('_score');
      return e;
    }).toList(growable: false);

    return out;
  }
}
