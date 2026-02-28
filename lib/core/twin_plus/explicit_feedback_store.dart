import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Append-only explicit feedback log (opt-in surface signals).
/// Stored locally as JSONL, pruned to a max number of entries.
class ExplicitFeedbackStore {
  static const _fileName = 'twin_explicit_feedback.jsonl';
  static const int _maxEntries = 2000;

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<void> append({
    required String surface,
    required String actor,
    String? decisionId,
    int? vote, // 1, -1, or 0/null
    bool? wrongSource,
    String? reason,
    String? details,
    Map<String, dynamic>? meta,
    int? tsEpochMs,
  }) async {
    final f = await _file();
    final now = tsEpochMs ?? DateTime.now().millisecondsSinceEpoch;
    final entry = <String, dynamic>{
      'tsEpochMs': now,
      'surface': surface,
      'actor': actor,
      if (decisionId != null) 'decisionId': decisionId,
      if (vote != null) 'vote': vote,
      if (wrongSource != null) 'wrongSource': wrongSource,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
      if (meta != null && meta.isNotEmpty) 'meta': meta,
    };

    await f.parent.create(recursive: true);
    await f.writeAsString('${jsonEncode(entry)}\n', mode: FileMode.append, flush: true);

    await _pruneIfNeeded(f);
  }

  static Future<void> _pruneIfNeeded(File f) async {
    if (!await f.exists()) return;
    final lines = await f.readAsLines();
    if (lines.length <= _maxEntries) return;

    final keep = lines.sublist(lines.length - _maxEntries);
    await f.writeAsString('${keep.join('\n')}\n', flush: true);
  }

  static Future<List<Map<String, dynamic>>> loadRecent({int limit = 200}) async {
    final f = await _file();
    if (!await f.exists()) return <Map<String, dynamic>>[];
    final lines = await f.readAsLines();
    final start = lines.length > limit ? lines.length - limit : 0;

    final out = <Map<String, dynamic>>[];
    for (final line in lines.sublist(start)) {
      final t = line.trim();
      if (t.isEmpty) continue;
      try {
        final m = jsonDecode(t);
        if (m is Map<String, dynamic>) out.add(m);
      } catch (_) {
        // ignore corrupt lines
      }
    }
    return out;
  }
}
