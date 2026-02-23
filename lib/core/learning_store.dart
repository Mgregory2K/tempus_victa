import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum SignalActionType { toTask, toCorkboard, recycled, acked }

class LearnedSource {
  final String source; // package or app name
  final int total;
  final int toTask;
  final int toCorkboard;
  final int recycled;
  final int acked;

  const LearnedSource({
    required this.source,
    required this.total,
    required this.toTask,
    required this.toCorkboard,
    required this.recycled,
    required this.acked,
  });

  Map<String, dynamic> toJson() => {
        'source': source,
        'total': total,
        'toTask': toTask,
        'toCorkboard': toCorkboard,
        'recycled': recycled,
        'acked': acked,
      };

  static LearnedSource fromJson(Map<String, dynamic> j) => LearnedSource(
        source: (j['source'] ?? '') as String,
        total: (j['total'] ?? 0) as int,
        toTask: (j['toTask'] ?? 0) as int,
        toCorkboard: (j['toCorkboard'] ?? 0) as int,
        recycled: (j['recycled'] ?? 0) as int,
        acked: (j['acked'] ?? 0) as int,
      );
}

class SuggestedRule {
  final String type; // mute / autoTask / autoCork
  final String source;
  final double confidence; // 0..1
  final String reason;

  const SuggestedRule({required this.type, required this.source, required this.confidence, required this.reason});

  Map<String, dynamic> toJson() => {'type': type, 'source': source, 'confidence': confidence, 'reason': reason};

  static SuggestedRule fromJson(Map<String, dynamic> j) => SuggestedRule(
        type: (j['type'] ?? '') as String,
        source: (j['source'] ?? '') as String,
        confidence: ((j['confidence'] ?? 0) as num).toDouble(),
        reason: (j['reason'] ?? '') as String,
      );
}

class LearningStore {
  static const _fileName = 'learning_signals_v1.json';

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  static Future<Map<String, dynamic>> _readRaw() async {
    final f = await _file();
    if (!await f.exists()) return {'version': 1, 'sources': <String, dynamic>{}, 'updatedAtUtc': DateTime.now().toUtc().toIso8601String()};
    final txt = await f.readAsString();
    return (jsonDecode(txt) as Map).cast<String, dynamic>();
  }

  static Future<void> _writeRaw(Map<String, dynamic> raw) async {
    final f = await _file();
    raw['updatedAtUtc'] = DateTime.now().toUtc().toIso8601String();
    await f.create(recursive: true);
    await f.writeAsString(jsonEncode(raw), flush: true);
  }

  static Future<void> record(String source, SignalActionType action) async {
    final raw = await _readRaw();
    final sources = (raw['sources'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    final cur = (sources[source] as Map?)?.cast<String, dynamic>() ??
        {'source': source, 'total': 0, 'toTask': 0, 'toCorkboard': 0, 'recycled': 0, 'acked': 0};

    cur['total'] = (cur['total'] as int) + 1;

    switch (action) {
      case SignalActionType.toTask:
        cur['toTask'] = (cur['toTask'] as int) + 1;
        break;
      case SignalActionType.toCorkboard:
        cur['toCorkboard'] = (cur['toCorkboard'] as int) + 1;
        break;
      case SignalActionType.recycled:
        cur['recycled'] = (cur['recycled'] as int) + 1;
        break;
      case SignalActionType.acked:
        cur['acked'] = (cur['acked'] as int) + 1;
        break;
    }

    sources[source] = cur;
    raw['sources'] = sources;
    await _writeRaw(raw);
  }

  static Future<List<LearnedSource>> listSources() async {
    final raw = await _readRaw();
    final sources = (raw['sources'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return sources.values
        .whereType<Map>()
        .map((m) => LearnedSource.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false)
      ..sort((a, b) => b.total.compareTo(a.total));
  }

  static List<SuggestedRule> suggest(List<LearnedSource> sources) {
    // Minimum samples before we act like we "learned" something.
    const min = 6;
    final out = <SuggestedRule>[];

    for (final s in sources) {
      if (s.total < min) continue;

      final recycleRate = s.recycled / s.total;
      final taskRate = s.toTask / s.total;
      final corkRate = s.toCorkboard / s.total;

      if (recycleRate >= 0.80) {
        out.add(SuggestedRule(
          type: 'mute',
          source: s.source,
          confidence: (recycleRate).clamp(0.0, 1.0),
          reason: 'You recycle ~${(recycleRate * 100).round()}% of signals from this source.',
        ));
      } else if (taskRate >= 0.60) {
        out.add(SuggestedRule(
          type: 'autoTask',
          source: s.source,
          confidence: (taskRate).clamp(0.0, 1.0),
          reason: 'You create tasks from ~${(taskRate * 100).round()}% of signals from this source.',
        ));
      } else if (corkRate >= 0.55) {
        out.add(SuggestedRule(
          type: 'autoCork',
          source: s.source,
          confidence: (corkRate).clamp(0.0, 1.0),
          reason: 'You pin ~${(corkRate * 100).round()}% of signals from this source to the Corkboard.',
        ));
      }
    }

    out.sort((a, b) => b.confidence.compareTo(a.confidence));
    return out.take(8).toList(growable: false);
  }
}
