import 'dart:math';

import 'twin_preference_ledger.dart';
import 'twin_feature_store.dart';

enum TaskType { personalState, appHowto, localSearch, webFact, planning, routing, events, travel, unknown }

/// Lightweight, deterministic intent classifier.
///
/// Goal: decide when the app should prefer *web verification* vs pure LLM,
/// and avoid treating obvious follow-ups as brand-new threads.
///
/// This is intentionally simple and inspectable; it can evolve over time.
class IntentSignals {
  final bool needsVerifiableFacts;
  final bool isFollowUp;
  final TaskType taskType;

  const IntentSignals({
    required this.needsVerifiableFacts,
    required this.isFollowUp,
    required this.taskType,
  });

  static IntentSignals analyze(String text, {required List<String> recentUserTurns}) {
    final q = text.trim().toLowerCase();

    // Follow-up heuristic: short + referential language.
    final isFollowUp = q.length < 80 && RegExp(r'^(and|also|what about|how about|then|ok|okay|so|why|wait|follow up|what if)\b').hasMatch(q);
    final hasRecentContext = recentUserTurns.isNotEmpty;

    // Time-sensitive / verifiable facts heuristic.
    final timeWords = RegExp(r'\b(today|now|current|latest|recent|this week|this month|yesterday|tomorrow|right now)\b').hasMatch(q);
    final whoWon = RegExp(r'\b(who won|winner|score|standings|schedule|result)\b').hasMatch(q);
    final money = RegExp(r'\b(price|cost|rate|deal|cheapest)\b').hasMatch(q);
    final weather = RegExp(r'\b(weather|forecast)\b').hasMatch(q);
    final lastEvent = RegExp(r'\b(last|most recent)\s+(super bowl|world cup|election|oscar|grammy|nba finals|mlb world series|nfl|nhl)\b').hasMatch(q);
    final explicitVerify = RegExp(r'\b(source|cite|citation|link|verify|look up|search the web|google)\b').hasMatch(q);

    final needsVerifiableFacts = timeWords || whoWon || money || weather || lastEvent || explicitVerify;

    // Task type heuristic.
    final appHowto = RegExp(r'\b(how do i|where do i|how to|settings|toggle|turn on|turn off|enable|disable)\b').hasMatch(q);
    final taskType = needsVerifiableFacts && !appHowto
        ? TaskType.webFact
        : appHowto
            ? TaskType.appHowto
            : TaskType.planning;

    return IntentSignals(
      needsVerifiableFacts: needsVerifiableFacts,
      isFollowUp: isFollowUp && hasRecentContext,
      taskType: taskType,
    );
  }
}

class QueryIntent {
  final String surface;
  final String queryText;
  final TaskType taskType;

  /// 'now'|'today'|'week'|'month'|'timeless'
  final String timeHorizon;

  final bool needsVerifiableFacts;
  final DateTime? deadlineUtc;
  final List<String> recentUserTurns;

  const QueryIntent({
    required this.surface,
    required this.queryText,
    this.taskType = TaskType.unknown,
    this.timeHorizon = 'today',
    this.needsVerifiableFacts = false,
    this.deadlineUtc,
    this.recentUserTurns = const <String>[],
  });
}

/// Numeric weights are used everywhere (0.0–1.0), quantized to 0.1 increments.
/// This avoids over-weighting any single action and keeps learning incremental.
class RoutePlan {
  final String decisionId;

  /// local_only|local_then_web|web_then_llm|local_then_llm|local_then_web_then_llm
  final String strategy;

  /// 0.0–1.0 (0.1 increments). Higher means "more time-sensitive".
  final double timeSensitivityW;

  /// 0.0–1.0 (0.1 increments). Higher means "requires verifiable sources".
  final double verifiabilityW;

  final bool aiAllowed;

  /// openai|gemini|none
  final String aiProvider;

  final int budgetTokensMax;
  final int cacheTtlSeconds;
  final List<String> reasonCodes;

  const RoutePlan({
    required this.decisionId,
    required this.strategy,
    required this.timeSensitivityW,
    required this.verifiabilityW,
    required this.aiAllowed,
    required this.aiProvider,
    required this.budgetTokensMax,
    required this.cacheTtlSeconds,
    required this.reasonCodes,
  });
}

double _q01(double v) {
  final clamped = v.clamp(0.0, 1.0);
  return (clamped * 10.0).round() / 10.0;
}

class TwinRouter {
  final TwinPreferenceLedger prefs;
  final TwinFeatureStore features;

  TwinRouter({required this.prefs, required this.features});

  RoutePlan route(QueryIntent intent) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();

    // Router-level deterministic signals so callers can't accidentally disable them.
    // (Callers should pass recent user turns; if they don't, we still behave safely.)
    final sig = IntentSignals.analyze(intent.queryText, recentUserTurns: intent.recentUserTurns);
    final effectiveNeedsFacts = intent.needsVerifiableFacts || sig.needsVerifiableFacts;
    final effectiveTaskType = (intent.taskType == TaskType.unknown) ? sig.taskType : intent.taskType;

    // Determine numeric time-sensitivity weight.
    final hasDeadline = intent.deadlineUtc != null;
    final horizon = intent.timeHorizon;
    // Base weights (quantized later)
    double timeW = 0.3;
    if (horizon == 'timeless') timeW = 0.1;
    if (horizon == 'month') timeW = 0.3;
    if (horizon == 'week') timeW = 0.5;
    if (horizon == 'today') timeW = 0.8;
    if (horizon == 'now') timeW = 1.0;
    if (hasDeadline) timeW = max(timeW, 0.9);

    // Determine numeric verifiability weight.
    // Weights are incremental; no single action jumps to a deterministic bucket.
    double verW = 0.0;
    if (effectiveNeedsFacts || effectiveTaskType == TaskType.webFact || effectiveTaskType == TaskType.events) {
      // Baseline need for verification.
      verW = 0.7;
      // User preference for fresh/verified data nudges upward, not flips.
      verW = verW + (prefs.hatesStaleInfo * 0.3);
    } else if (effectiveTaskType == TaskType.travel) {
      verW = 0.5 + (prefs.hatesStaleInfo * 0.2);
    } else {
      // Planning/personal state: verification is optional but can exist.
      verW = 0.2 + (prefs.hatesStaleInfo * 0.1);
    }

    timeW = _q01(timeW);
    verW = _q01(verW);

    // Determine AI allowance (respects opt-in).
    final aiAllowed = prefs.aiOptIn;

    // Strategy:
    // - app how-to: local_only
    // - travel/events/web facts: local_then_web_then_llm if AI allowed, else local_then_web
    // - planning: local_then_llm if AI allowed, else local_then_web (fallback links)
    // - routing: local_then_web (AI optional)
    String strategy = 'local_only';
    final reasons = <String>[];

    if (effectiveTaskType == TaskType.appHowto) {
      strategy = 'local_only';
      reasons.add('app_howto');
    } else if (effectiveTaskType == TaskType.routing) {
      strategy = 'local_then_web';
      reasons.add('routing');
    } else if (effectiveTaskType == TaskType.events || effectiveTaskType == TaskType.webFact || effectiveTaskType == TaskType.travel || effectiveNeedsFacts) {
      strategy = aiAllowed ? 'local_then_web_then_llm' : 'local_then_web';
      reasons.add('verifiable_external');
    } else if (effectiveTaskType == TaskType.planning) {
      strategy = aiAllowed ? 'local_then_llm' : 'local_then_web';
      reasons.add('planning');
    } else if (verW >= 0.6) {
      strategy = aiAllowed ? 'local_then_web_then_llm' : 'local_then_web';
      reasons.add('needs_verifiable');
    } else if (aiAllowed) {
      strategy = 'local_then_llm';
      reasons.add('ai_opt_in');
    } else {
      strategy = 'local_then_web';
      reasons.add('ai_off');
    }

    if (timeW >= 0.8) reasons.add('time_pressure');
    if (prefs.hatesVerbose >= 0.35) reasons.add('prefers_short');

    // Budget selection.
    int budget = 450; // default
    if (prefs.lengthDefault == 'tiny') budget = 180;
    if (prefs.lengthDefault == 'short') budget = 320;
    if (prefs.lengthDefault == 'long') budget = 900;

    // Cache TTL (seconds), scaled by time-sensitivity.
    int ttl = 3600;
    if (timeW >= 0.8) ttl = 900;
    if (timeW >= 0.9) ttl = 600;
    if (effectiveTaskType == TaskType.appHowto) ttl = 86400 * 30;
    if (effectiveTaskType == TaskType.travel) ttl = 86400;
    if (effectiveTaskType == TaskType.events) ttl = 21600;

    final aiProvider = aiAllowed ? 'openai' : 'none';

    return RoutePlan(
      decisionId: id,
      strategy: strategy,
      timeSensitivityW: timeW,
      verifiabilityW: verW,
      aiAllowed: aiAllowed,
      aiProvider: aiProvider,
      budgetTokensMax: budget,
      cacheTtlSeconds: ttl,
      reasonCodes: reasons,
    );
  }
}
