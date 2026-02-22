import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AppSynonymEntry {
  final String phrase; // normalized
  final String capabilityId;
  final int count;
  final int lastUsedEpochMs;

  const AppSynonymEntry({
    required this.phrase,
    required this.capabilityId,
    required this.count,
    required this.lastUsedEpochMs,
  });

  AppSynonymEntry copyWith({
    String? phrase,
    String? capabilityId,
    int? count,
    int? lastUsedEpochMs,
  }) {
    return AppSynonymEntry(
      phrase: phrase ?? this.phrase,
      capabilityId: capabilityId ?? this.capabilityId,
      count: count ?? this.count,
      lastUsedEpochMs: lastUsedEpochMs ?? this.lastUsedEpochMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'phrase': phrase,
        'capabilityId': capabilityId,
        'count': count,
        'lastUsedEpochMs': lastUsedEpochMs,
      };

  static AppSynonymEntry fromJson(Map<String, dynamic> j) {
    return AppSynonymEntry(
      phrase: (j['phrase'] ?? '').toString(),
      capabilityId: (j['capabilityId'] ?? '').toString(),
      count: (j['count'] is int) ? j['count'] as int : int.tryParse('${j['count']}') ?? 0,
      lastUsedEpochMs: (j['lastUsedEpochMs'] is int)
          ? j['lastUsedEpochMs'] as int
          : int.tryParse('${j['lastUsedEpochMs']}') ?? 0,
    );
  }
}

class AppSynonymsStore {
  static const String _kKey = 'app_synonyms_v1';
  static const int _maxEntries = 200;

  static String normalize(String s) {
    var x = s.toLowerCase().trim();
    x = x.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    x = x.replaceAll(RegExp(r'\s+'), ' ').trim();
    return x;
  }

  static Future<Map<String, AppSynonymEntry>> _loadMap() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, AppSynonymEntry>{};
      decoded.forEach((k, v) {
        if (k is String && v is Map) {
          out[k] = AppSynonymEntry.fromJson(v.cast<String, dynamic>());
        }
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveMap(Map<String, AppSynonymEntry> m) async {
    if (m.length > _maxEntries) {
      final entries = m.values.toList()
        ..sort((a, b) {
          final c = a.count.compareTo(b.count);
          if (c != 0) return c;
          return a.lastUsedEpochMs.compareTo(b.lastUsedEpochMs);
        });
      final removeCount = m.length - _maxEntries;
      for (var i = 0; i < removeCount; i++) {
        m.remove(entries[i].phrase);
      }
    }

    final sp = await SharedPreferences.getInstance();
    final jsonMap = <String, dynamic>{};
    for (final e in m.values) {
      jsonMap[e.phrase] = e.toJson();
    }
    await sp.setString(_kKey, jsonEncode(jsonMap));
  }

  static Future<void> reinforce({
    required String rawPhrase,
    required String capabilityId,
  }) async {
    final phrase = normalize(rawPhrase);
    if (phrase.isEmpty || capabilityId.trim().isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final m = await _loadMap();

    final existing = m[phrase];
    if (existing == null) {
      m[phrase] = AppSynonymEntry(
        phrase: phrase,
        capabilityId: capabilityId,
        count: 1,
        lastUsedEpochMs: now,
      );
    } else {
      m[phrase] = existing.copyWith(
        capabilityId: capabilityId,
        count: existing.count + 1,
        lastUsedEpochMs: now,
      );
    }

    await _saveMap(m);
  }

  static Future<String?> lookupCapabilityId(String rawPhrase) async {
    final phrase = normalize(rawPhrase);
    if (phrase.isEmpty) return null;

    final m = await _loadMap();
    final entry = m[phrase];
    if (entry == null || entry.capabilityId.trim().isEmpty) return null;

    return entry.capabilityId;
  }
}
