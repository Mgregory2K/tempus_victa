// Tempus Victa - Learning Engine
// "Everything is measured and weighted."
//
// This file intentionally implements a deterministic, local-first learning loop.
// AI can suggest; the local weights decide.

import 'dart:convert';

import '../../data/db/app_db.dart';
import '../../data/models/ids.dart';


class RouteSuggestion {
  final String bucket;
  final double confidence; // 0..1
  const RouteSuggestion(this.bucket, this.confidence);
}

class LearningEngine {
  LearningEngine._();
  static final LearningEngine instance = LearningEngine._();

  static const _kRoute = 'route:';
  static const _kDismiss = 'dismiss:';
  static const _kComplete = 'complete:';

  Future<void> bumpRoute({required String fromSource, required String toBucket, double delta = 1}) async {
    final key = '$_kRoute$fromSource->$toBucket';
    final current = await AppDb.instance.getWeight(key);
    await AppDb.instance.setWeight(key, current + delta);

    await _event(
      eventType: 'route',
      entityType: 'signal',
      entityId: '',
      source: fromSource,
      payload: {'to': toBucket},
      scoreDelta: delta,
    );
  }

  Future<void> bumpDismiss({required String fromSource, double delta = 1}) async {
    final key = '$_kDismiss$fromSource';
    final current = await AppDb.instance.getWeight(key);
    await AppDb.instance.setWeight(key, current + delta);

    await _event(
      eventType: 'dismiss',
      entityType: 'signal',
      entityId: '',
      source: fromSource,
      payload: {},
      scoreDelta: delta,
    );
  }

  Future<void> bumpComplete({required String fromSource, required String taskId, double delta = 1}) async {
    final key = '$_kComplete$fromSource';
    final current = await AppDb.instance.getWeight(key);
    await AppDb.instance.setWeight(key, current + delta);

    await _event(
      eventType: 'complete',
      entityType: 'task',
      entityId: taskId,
      source: fromSource,
      payload: {},
      scoreDelta: delta,
    );
  }

  Future<void> noteAiClassification({
    required String model,
    required String inputText,
    required String predictedBucket,
    required double confidence,
  }) async {
    await _event(
      eventType: 'ai_classify',
      entityType: 'signal',
      entityId: '',
      source: 'ai',
      payload: {
        'model': model,
        'bucket': predictedBucket,
        'confidence': confidence,
        'sample': inputText.length > 160 ? inputText.substring(0, 160) : inputText,
      },
      scoreDelta: confidence,
    );
  }

  
  /// Suggest a routing bucket based on learned weights for a given source.
  ///
  /// Returns null if there is not enough learned data yet.
  Future<RouteSuggestion?> suggestRoute({required String source}) async {
    // We store route weights under: route:<fromSource>-><bucket>
    final prefix = '$_kRoute$source->';

    // AppDb stores weights in a table; we don't have prefix scanning, so we keep a known set of buckets.
    const buckets = <String>['inbox', 'tasks', 'projects', 'corkboard', 'recycle', 'signals'];

    final weights = <String, double>{};
    for (final b in buckets) {
      final w = await AppDb.instance.getWeight(prefix + b);
      if (w > 0) weights[b] = w;
    }
    if (weights.isEmpty) return null;

    final total = weights.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return null;

    // Pick max weight bucket; confidence is normalized share.
    String bestBucket = weights.keys.first;
    double bestW = -1;
    weights.forEach((k, v) {
      if (v > bestW) {
        bestW = v;
        bestBucket = k;
      }
    });

    final confidence = (bestW / total).clamp(0.0, 1.0);
    return RouteSuggestion(bestBucket, confidence);
  }

Future<void> _event({
    required String eventType,
    required String entityType,
    required String entityId,
    required String source,
    required Map<String, Object?> payload,
    required double scoreDelta,
  }) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await AppDb.instance.addLearningEvent({
      'id': Ids.newId(),
      'event_type': eventType,
      'entity_type': entityType,
      'entity_id': entityId,
      'source': source,
      'payload_json': jsonEncode(payload),
      'score_delta': scoreDelta,
      'occurred_at_utc': now,
    });
  }
}
