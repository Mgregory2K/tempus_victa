import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local-first, lightweight feedback stats for Signal Bay.
///
/// This is intentionally NOT Drift yet. We keep it tiny and fast so Signal Bay
/// can score signals deterministically without touching the heavier DB layer.
///
/// Stored as a single JSON blob in SharedPreferences:
/// {
///   "bySource": {"com.app": {"opened":1, "promoted":0, ...}},
///   "byFingerprint": {"pkg|title|body": {...}}
/// }
class SignalFeedbackStore {
  static const String _kKey = 'tempus.signal.feedback.v1';

  static Future<SignalFeedbackSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return const SignalFeedbackSnapshot();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const SignalFeedbackSnapshot();
      return SignalFeedbackSnapshot.fromJson(decoded);
    } catch (_) {
      return const SignalFeedbackSnapshot();
    }
  }

  static Future<void> save(SignalFeedbackSnapshot snap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(snap.toJson()));
  }

  static Future<void> bumpSource(String source, String field, [int by = 1]) async {
    final snap = await load();
    final next = snap.bumpSource(source, field, by);
    await save(next);
  }

  static Future<void> bumpFingerprint(String fingerprint, String field, [int by = 1]) async {
    final snap = await load();
    final next = snap.bumpFingerprint(fingerprint, field, by);
    await save(next);
  }
}

class SignalFeedbackSnapshot {
  final Map<String, SignalFeedbackStats> bySource;
  final Map<String, SignalFeedbackStats> byFingerprint;

  const SignalFeedbackSnapshot({
    this.bySource = const <String, SignalFeedbackStats>{},
    this.byFingerprint = const <String, SignalFeedbackStats>{},
  });

  SignalFeedbackSnapshot bumpSource(String source, String field, int by) {
    final cur = bySource[source] ?? const SignalFeedbackStats();
    final nextStats = cur.bump(field, by);
    final nextMap = Map<String, SignalFeedbackStats>.from(bySource);
    nextMap[source] = nextStats;
    return SignalFeedbackSnapshot(bySource: nextMap, byFingerprint: byFingerprint);
  }

  SignalFeedbackSnapshot bumpFingerprint(String fp, String field, int by) {
    final cur = byFingerprint[fp] ?? const SignalFeedbackStats();
    final nextStats = cur.bump(field, by);
    final nextMap = Map<String, SignalFeedbackStats>.from(byFingerprint);
    nextMap[fp] = nextStats;
    return SignalFeedbackSnapshot(bySource: bySource, byFingerprint: nextMap);
  }

  SignalFeedbackStats statsForSource(String source) => bySource[source] ?? const SignalFeedbackStats();
  SignalFeedbackStats statsForFingerprint(String fp) => byFingerprint[fp] ?? const SignalFeedbackStats();

  Map<String, dynamic> toJson() => {
        'bySource': bySource.map((k, v) => MapEntry(k, v.toJson())),
        'byFingerprint': byFingerprint.map((k, v) => MapEntry(k, v.toJson())),
      };

  static SignalFeedbackSnapshot fromJson(Map<String, dynamic> j) {
    final srcRaw = j['bySource'];
    final fpRaw = j['byFingerprint'];

    final src = <String, SignalFeedbackStats>{};
    if (srcRaw is Map) {
      for (final e in srcRaw.entries) {
        final k = e.key.toString();
        final v = e.value;
        if (v is Map<String, dynamic>) {
          src[k] = SignalFeedbackStats.fromJson(v);
        } else if (v is Map) {
          src[k] = SignalFeedbackStats.fromJson(v.map((kk, vv) => MapEntry(kk.toString(), vv)));
        }
      }
    }

    final fp = <String, SignalFeedbackStats>{};
    if (fpRaw is Map) {
      for (final e in fpRaw.entries) {
        final k = e.key.toString();
        final v = e.value;
        if (v is Map<String, dynamic>) {
          fp[k] = SignalFeedbackStats.fromJson(v);
        } else if (v is Map) {
          fp[k] = SignalFeedbackStats.fromJson(v.map((kk, vv) => MapEntry(kk.toString(), vv)));
        }
      }
    }

    return SignalFeedbackSnapshot(bySource: src, byFingerprint: fp);
  }
}

class SignalFeedbackStats {
  final int opened;
  final int promoted;
  final int acknowledged;
  final int recycled;
  final int muted;

  const SignalFeedbackStats({
    this.opened = 0,
    this.promoted = 0,
    this.acknowledged = 0,
    this.recycled = 0,
    this.muted = 0,
  });

  SignalFeedbackStats bump(String field, int by) {
    switch (field) {
      case 'opened':
        return SignalFeedbackStats(
          opened: opened + by,
          promoted: promoted,
          acknowledged: acknowledged,
          recycled: recycled,
          muted: muted,
        );
      case 'promoted':
        return SignalFeedbackStats(
          opened: opened,
          promoted: promoted + by,
          acknowledged: acknowledged,
          recycled: recycled,
          muted: muted,
        );
      case 'acknowledged':
        return SignalFeedbackStats(
          opened: opened,
          promoted: promoted,
          acknowledged: acknowledged + by,
          recycled: recycled,
          muted: muted,
        );
      case 'recycled':
        return SignalFeedbackStats(
          opened: opened,
          promoted: promoted,
          acknowledged: acknowledged,
          recycled: recycled + by,
          muted: muted,
        );
      case 'muted':
        return SignalFeedbackStats(
          opened: opened,
          promoted: promoted,
          acknowledged: acknowledged,
          recycled: recycled,
          muted: muted + by,
        );
      default:
        return this;
    }
  }

  Map<String, dynamic> toJson() => {
        'opened': opened,
        'promoted': promoted,
        'acknowledged': acknowledged,
        'recycled': recycled,
        'muted': muted,
      };

  static SignalFeedbackStats fromJson(Map<String, dynamic> j) {
    int i(String k) => (j[k] is int) ? j[k] as int : int.tryParse('${j[k] ?? 0}') ?? 0;
    return SignalFeedbackStats(
      opened: i('opened'),
      promoted: i('promoted'),
      acknowledged: i('acknowledged'),
      recycled: i('recycled'),
      muted: i('muted'),
    );
  }
}
