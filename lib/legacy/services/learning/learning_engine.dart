// lib/services/learning/learning_engine.dart
//
// Canonical, local-first Learning Engine (no AI calls).
// Stable API surface to avoid breaking UI files.
//
// Usage:
//   await LearningEngine.I.init();
//   LearningEngine.instance.recordTelemetry(eventName: 'open', surface: 'signals');
//   LearningEngine.instance.recordIntent(intent: 'user_input', text: 'hello');

import 'dart:async';

import 'telemetry_store.dart';
import 'trust_engine.dart';
import 'lexicon_engine.dart';

class LearningEngine {
  LearningEngine._();

  static final LearningEngine instance = LearningEngine._();

  // Back-compat alias (you use LearningEngine.I in main.dart)
  static LearningEngine get I => instance;

  bool _initialized = false;

  final TelemetryStore _telemetry = TelemetryStore.instance;
  final TrustEngine _trust = TrustEngine.instance;
  final LexiconEngine _lexicon = LexiconEngine();

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    // Init order: storage first, then engines that depend on storage
    await _telemetry.init();
    await _trust.init();
    await _lexicon.init();

    _initialized = true;
  }

  // ---------- Public API (canonical) ----------

  Future<void> recordTelemetry({
    required String eventName,
    String? surface,
    String? module,
    String? source,
    String? entityType,
    String? entityId,
    double? weight,
    Map<String, dynamic>? data,
    DateTime? at,
  }) async {
    await _ensureInit();

    final payload = <String, dynamic>{
      'kind': 'telemetry',
      'at': (at ?? DateTime.now()).toUtc().toIso8601String(),
      'event': eventName,
    };

    if (surface != null) payload['surface'] = surface;
    if (module != null) payload['module'] = module;
    if (source != null) payload['source'] = source;
    if (entityType != null) payload['entityType'] = entityType;
    if (entityId != null) payload['entityId'] = entityId;
    if (weight != null) payload['weight'] = weight;
    if (data != null && data.isNotEmpty) payload['data'] = data;

    await _telemetry.append(payload);

    // Trust reinforcement/demotion hooks (silent, never crash UI)
    // Rule: if an entity is involved, treat interaction as reinforcement by default.
    // You can demote explicitly by calling demoteTrust() below.
    if (entityType != null && entityId != null) {
      await _safe(() => _trust.reinforce(entityType: entityType, entityId: entityId, delta: 0.01));
    }
  }

  Future<void> recordIntent({
    required String intent,
    String? text,
    String? surface,
    String? module,
    String? sender,
    double? confidence,
    double? urgency,
    List<Map<String, dynamic>>? entities,
    Map<String, dynamic>? data,
    DateTime? at,
  }) async {
    await _ensureInit();

    final cleaned = text?.trim();
    final payload = <String, dynamic>{
      'kind': 'intent',
      'at': (at ?? DateTime.now()).toUtc().toIso8601String(),
      'intent': intent,
    };

    if (cleaned != null && cleaned.isNotEmpty) payload['text'] = cleaned;
    if (surface != null) payload['surface'] = surface;
    if (module != null) payload['module'] = module;
    if (sender != null) payload['sender'] = sender;
    if (confidence != null) payload['confidence'] = confidence;
    if (urgency != null) payload['urgency'] = urgency;
    if (entities != null && entities.isNotEmpty) payload['entities'] = entities;
    if (data != null && data.isNotEmpty) payload['data'] = data;

    await _telemetry.append(payload);

    // Lexicon learning: learn from user text (silent; never break UI)
    if (cleaned != null && cleaned.isNotEmpty) {
      await _safe(() => _lexicon.processText(cleaned));
    }

    // Trust: if sender is present, reinforce sender a bit
    if (sender != null && sender.trim().isNotEmpty) {
      await _safe(() => _trust.reinforce(entityType: 'contact', entityId: sender.trim(), delta: 0.01));
    }
  }

  // Convenience helper: old UI code wants “tap”
  Future<void> tap({
    required String what,
    String? surface,
    String? module,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? data,
    double? weight,
  }) async {
    await recordTelemetry(
      eventName: what,
      surface: surface,
      module: module,
      entityType: entityType,
      entityId: entityId,
      weight: weight,
      data: data,
    );
  }

  // Explicit trust controls (for things like "mark noise")
  Future<void> demoteTrust({
    required String entityType,
    required String entityId,
    double delta = 0.03,
  }) async {
    await _ensureInit();
    await _safe(() => _trust.demote(entityType: entityType, entityId: entityId, delta: delta));
  }

  Future<void> reinforceTrust({
    required String entityType,
    required String entityId,
    double delta = 0.02,
  }) async {
    await _ensureInit();
    await _safe(() => _trust.reinforce(entityType: entityType, entityId: entityId, delta: delta));
  }

  // ---------- Internals ----------

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await init();
  }

  Future<void> _safe(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (_) {
      // learning must never crash UI
    }
  }
}
