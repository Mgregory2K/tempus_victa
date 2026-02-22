import 'dart:async';
import 'dart:math' as math;

import '../../data/db/app_db.dart';
import '../../data/models/signal.dart';
import '../../data/repositories/automation_rule_repo.dart';
import '../../data/repositories/recycle_repo.dart';
import '../../data/repositories/signal_repo.dart';
import '../../data/repositories/task_repo.dart';
import '../learning/learning_engine.dart';
import '../logging/jsonl_logger.dart';

/// Tempus Victa - Automation Engine
///
/// "Autopilot" loop:
/// - Evaluate inbox Signals.
/// - Apply explicit enabled automation rules (local-first).
/// - Otherwise, use learned routing confidence.
/// - Execute when confidence crosses threshold.
/// - Every action is logged (JSONL) for auditability.
class AutomationEngine {
  AutomationEngine._();
  static final AutomationEngine instance = AutomationEngine._();

  Timer? _timer;
  bool _running = false;

  static const _kEnabled = 'automation:enabled';
  static const _kThreshold = 'automation:threshold'; // 0..1 (learned fallback)
  static const _kIntervalMs = 'automation:interval_ms';

  Future<void> start() async {
    if (_running) return;
    _running = true;

    final enabled = (await AppDb.instance.getMeta(_kEnabled))?.toLowerCase() != 'false';
    if (!enabled) return;

    final intervalMs = int.tryParse((await AppDb.instance.getMeta(_kIntervalMs)) ?? '') ?? 3500;

    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) async {
      try {
        await _tick();
      } catch (e) {
        await JsonlLogger.instance.log('automation_tick_error', {'error': e.toString()});
      }
    });

    await JsonlLogger.instance.log('automation_started', {'intervalMs': intervalMs});
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _running = false;
    await JsonlLogger.instance.log('automation_stopped', {});
  }

  Future<void> _tick() async {
    final enabled = (await AppDb.instance.getMeta(_kEnabled))?.toLowerCase() != 'false';
    if (!enabled) return;

    final learnedThreshold =
        double.tryParse((await AppDb.instance.getMeta(_kThreshold)) ?? '')?.clamp(0.0, 1.0) ?? 0.85;

    // Pull a small batch of inbox signals.
    final inbox = await SignalRepo.instance.list(status: 'inbox');
    if (inbox.isEmpty) return;

    // Load enabled explicit rules.
    final rules = (await AutomationRuleRepo.instance.list(includeDisabled: false));

    // Evaluate newest-first.
    for (final s in inbox.take(25)) {
      final applied = await _applyExplicitRules(s, rules);
      if (applied) continue;

      // Learned fallback routing.
      final suggestion = await LearningEngine.instance.suggestRoute(source: s.source);
      if (suggestion == null) continue;

      final toBucket = suggestion.bucket;
      final confidence = suggestion.confidence;

      if (confidence >= learnedThreshold) {
        await _executeRoute(signal: s, toBucket: toBucket, confidence: confidence, reason: 'learned');
      }
    }
  }

  Future<bool> _applyExplicitRules(Signal s, List rules) async {
    for (final r in rules) {
      final trigger = (r.trigger as String).toLowerCase();
      final kind = s.kind.toLowerCase();
      final src = s.source.toLowerCase();

      final matches = trigger == kind || src.contains(trigger);
      if (!matches) continue;

      final confidence = math.max(s.confidence, s.weight);
      if (confidence < r.threshold) continue;

      final action = (r.action as String).toLowerCase();
      if (action.startsWith('route_to:')) {
        final bucket = action.split(':').skip(1).join(':').trim();
        await _executeRoute(signal: s, toBucket: bucket, confidence: confidence, reason: 'rule:${r.id}');
        return true;
      }
      if (action == 'recycle') {
        await RecycleRepo.instance.moveToRecycle(signal: s, reason: 'automation');
        await JsonlLogger.instance.log('automation_recycle', {
          'signalId': s.id,
          'reason': 'rule:${r.id}',
          'confidence': confidence,
        });
        return true;
      }
      if (action == 'create_task') {
        await TaskRepo.instance.create(
          title: s.text ?? s.transcript ?? '(Untitled)',
          details: 'From ${s.source}\nSignal ${s.id}',
          status: 'inbox',
          source: 'automation',
          signalId: s.id,
          capturedAtUtc: s.capturedAtUtc,
        );
        await RecycleRepo.instance.moveToRecycle(signal: s, reason: 'automation');
        await JsonlLogger.instance.log('automation_create_task', {
          'signalId': s.id,
          'reason': 'rule:${r.id}',
          'confidence': confidence,
        });
        return true;
      }
    }
    return false;
  }

  Future<void> _executeRoute({
    required Signal signal,
    required String toBucket,
    required double confidence,
    required String reason,
  }) async {
    final bucket = toBucket.trim().isEmpty ? 'inbox' : toBucket.trim();

    if (bucket == 'tasks' || bucket == 'actions') {
      await TaskRepo.instance.create(
        title: signal.text ?? signal.transcript ?? '(Untitled)',
        details: 'From ${signal.source}\nSignal ${signal.id}',
        status: 'inbox',
        source: 'automation',
        signalId: signal.id,
        capturedAtUtc: signal.capturedAtUtc,
      );
      await RecycleRepo.instance.moveToRecycle(signal: signal, reason: 'automation');
      await JsonlLogger.instance.log('automation_route_to_tasks', {
        'signalId': signal.id,
        'bucket': bucket,
        'confidence': confidence,
        'reason': reason,
      });
      return;
    }

    if (bucket == 'recycle') {
      await RecycleRepo.instance.moveToRecycle(signal: signal, reason: 'automation');
      await JsonlLogger.instance.log('automation_route_to_recycle', {
        'signalId': signal.id,
        'confidence': confidence,
        'reason': reason,
      });
      return;
    }

    // Default: update signal.status so it appears in the right Signal Bay bucket.
    await SignalRepo.instance.updateStatus(signal.id, bucket);
    await SignalRepo.instance.setWeight(signal.id, confidence);
    await JsonlLogger.instance.log('automation_route_signal', {
      'signalId': signal.id,
      'toBucket': bucket,
      'confidence': confidence,
      'reason': reason,
    });
  }
}
