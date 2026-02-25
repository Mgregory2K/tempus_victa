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

double _q01(double v) {
  final clamped = v.clamp(0.0, 1.0);
  return (clamped * 10.0).round() / 10.0;
}


class SourceLearningStats {
  final String source;
  final int total;
  final int toTask;
  final int toCorkboard;
  final int recycled;
  final int acked;

  const SourceLearningStats({
    required this.source,
    required this.total,
    required this.toTask,
    required this.toCorkboard,
    required this.recycled,
    required this.acked,
  });

  int countFor(SignalActionType a) {
    switch (a) {
      case SignalActionType.toTask:
        return toTask;
      case SignalActionType.toCorkboard:
        return toCorkboard;
      case SignalActionType.recycled:
        return recycled;
      case SignalActionType.acked:
        return acked;
    }
  }

  /// Returns dominant action among {toTask,toCorkboard,recycled} (acked excluded).
  SignalActionType dominantAction() {
    final m = <SignalActionType, int>{
      SignalActionType.toTask: toTask,
      SignalActionType.toCorkboard: toCorkboard,
      SignalActionType.recycled: recycled,
    };
    SignalActionType best = SignalActionType.toTask;
    int bestV = -1;
    m.forEach((k, v) {
      if (v > bestV) {
        bestV = v;
        best = k;
      }
    });
    return best;
  }

  double confidenceFor(SignalActionType a) {
    if (total <= 0) return 0.0;
    return _q01(countFor(a) / total);
  }

  /// Confidence of the dominant action (acked excluded).
  double dominantConfidence() => confidenceFor(dominantAction());

  bool meetsTrainingMinimum([int min = 25]) => total >= min;
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
    const min = 25;
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
          confidence: _q01(recycleRate),
          reason: 'You recycle ~${(recycleRate * 100).round()}% of signals from this source.',
        ));
      } else if (taskRate >= 0.60) {
        out.add(SuggestedRule(
          type: 'autoTask',
          source: s.source,
          confidence: _q01(taskRate),
          reason: 'You create tasks from ~${(taskRate * 100).round()}% of signals from this source.',
        ));
      } else if (corkRate >= 0.55) {
        out.add(SuggestedRule(
          type: 'autoCork',
          source: s.source,
          confidence: _q01(corkRate),
          reason: 'You pin ~${(corkRate * 100).round()}% of signals from this source to the Corkboard.',
        ));
      }
    }

    out.sort((a, b) => b.confidence.compareTo(a.confidence));
    return out.take(8).toList(growable: false);
  }

  /// Returns aggregated stats for a specific source.
  static Future<SourceLearningStats> statsForSource(String source) async {
    final raw = await _readRaw();
    final sources = (raw['sources'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final cur = (sources[source] as Map?)?.cast<String, dynamic>() ??
        {'source': source, 'total': 0, 'toTask': 0, 'toCorkboard': 0, 'recycled': 0, 'acked': 0};

    return SourceLearningStats(
      source: source,
      total: (cur['total'] ?? 0) as int,
      toTask: (cur['toTask'] ?? 0) as int,
      toCorkboard: (cur['toCorkboard'] ?? 0) as int,
      recycled: (cur['recycled'] ?? 0) as int,
      acked: (cur['acked'] ?? 0) as int,
    );
  }

  /// Suggests a dominant action for a single source once the training minimum is met.
  ///
  /// Returns null when:
  /// - total < minSamples
  /// - dominant confidence < suggestMinConfidence
  static Future<SignalActionType?> suggestActionForSource(
    String source, {
    int minSamples = 25,
    double suggestMinConfidence = 0.7,
  }) async {
    final s = await statsForSource(source);
    if (!s.meetsTrainingMinimum(minSamples)) return null;
    final dom = s.dominantAction();
    final conf = s.confidenceFor(dom);
    if (conf < suggestMinConfidence) return null;
    return dom;
  }

  static double suggestConfidenceThreshold() => 0.7;
  static double autoRouteEligibleThreshold() => 0.85;
  static int trainingMinimum() => 25;

}

