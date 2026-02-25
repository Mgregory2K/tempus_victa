import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'signal_item.dart';
import 'suggestion_result.dart';

class SuggestionEngine {
  static const String _kDismissed = 'tempus.suggestions.dismissed.v1';
  static const String _kApplied = 'tempus.suggestions.applied.v1';

  static Future<Set<String>> _loadSet(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return <String>{};
    try {
      final v = jsonDecode(raw);
      if (v is! List) return <String>{};
      return v.map((e) => '$e').toSet();
    } catch (_) {
      return <String>{};
    }
  }

  static Future<void> _saveSet(String key, Set<String> v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(v.toList()));
  }

  static Future<bool> isDismissed(String fingerprint) async {
    final s = await _loadSet(_kDismissed);
    return s.contains(fingerprint);
  }

  static Future<bool> isApplied(String fingerprint) async {
    final s = await _loadSet(_kApplied);
    return s.contains(fingerprint);
  }

  static Future<void> dismiss(String fingerprint) async {
    final s = await _loadSet(_kDismissed);
    s.add(fingerprint);
    await _saveSet(_kDismissed, s);
  }

  static Future<void> markApplied(String fingerprint) async {
    final s = await _loadSet(_kApplied);
    s.add(fingerprint);
    await _saveSet(_kApplied, s);
  }

  /// Best-effort, deterministic suggestions.
  /// - Never mutates data by itself.
  /// - Only returns a suggestion; UI must confirm.
  static SuggestionResult? suggestForSignal(SignalItem s) {
    final text = ('${s.title}\n${s.body ?? ''}').trim();
    if (text.isEmpty) return null;

    final lower = text.toLowerCase();

    // Determine list name only when strongly indicated (avoid guessing).
    String? listName;
    if (lower.contains('grocery')) listName = 'Grocery';
    if (lower.contains('home depot') || lower.contains('hardware store') || lower.contains('hardware')) listName ??= 'Hardware Store';
    if (lower.contains("lowe")) listName ??= "Lowe's";
    if (lower.contains('walmart')) listName ??= 'Walmart';

    if (listName == null) {
      // Without a clear destination list, we do not suggest.
      return null;
    }

    final items = _extractItems(text);
    if (items.length < 2) return null;

    // Confidence: proportional to item count (capped).
    final conf = (0.55 + (items.length.clamp(2, 10) - 2) * 0.05).clamp(0.55, 0.95).toDouble();

    return SuggestionResult(
      kind: 'list_add',
      listName: listName,
      items: items,
      confidence: conf,
    );
  }

  static List<String> _extractItems(String text) {
    final raw = text
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .trim();

    final out = <String>[];

    // Bullet lines
    for (final line in raw.split('\n')) {
      final l = line.trim();
      if (l.startsWith('- ') || l.startsWith('* ') || l.startsWith('•')) {
        final cleaned = l.replaceFirst(RegExp(r'^(-|\*|•)\s*'), '').trim();
        if (cleaned.isNotEmpty) out.add(cleaned);
      }
    }

    // Comma-separated chunks
    if (out.length < 2 && raw.contains(',')) {
      out.addAll(raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    }

    // De-dupe + sanitize
    final seen = <String>{};
    final cleaned = <String>[];
    for (final it in out) {
      final v = it.trim();
      if (v.isEmpty) continue;
      final key = v.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      // avoid enormous chunks
      if (v.length > 80) continue;
      cleaned.add(v);
    }
    return cleaned;
  }
}
