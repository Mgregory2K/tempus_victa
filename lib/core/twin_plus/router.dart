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
  final String timeHorizon; // now|today|week|month|timeless
  final bool needsVerifiableFacts;
  final DateTime? deadlineUtc;

  const QueryIntent({
    required this.surface,
    required this.queryText,
    this.taskType = TaskType.unknown,
    this.timeHorizon = 'today',
    this.needsVerifiableFacts = false,
    this.deadlineUtc,
  });
}

class RoutePlan {
  final String decisionId;
  final String strategy; // local_only|local_then_web|web_then_llm|local_then_llm|local_then_web_then_llm
  final String timeSensitivity; // low|med|high
  final String verifiability; // none|preferred|required
  final bool aiAllowed;
  final String aiProvider; // openai|gemini|none
  final int budgetTokensMax;
  final int cacheTtlSeconds;
  final List<String> reasonCodes;

  const RoutePlan({
    required this.decisionId,
    required this.strategy,
    required this.timeSensitivity,
    required this.verifiability,
    required this.aiAllowed,
    required this.aiProvider,
    required this.budgetTokensMax,
    required this.cacheTtlSeconds,
    required this.reasonCodes,
  });
}

class TwinRouter {
  final TwinPreferenceLedger prefs;
  final TwinFeatureStore features;

  TwinRouter({required this.prefs, required this.features});

  RoutePlan route(QueryIntent intent) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final q = intent.queryText.trim();

    // Router-level deterministic signals so callers can't accidentally disable them.
    final sig = IntentSignals.analyze(intent.queryText, recentUserTurns: const []);
    final effectiveNeedsFacts = intent.needsVerifiableFacts || sig.needsVerifiableFacts;
    final effectiveTaskType = (intent.taskType == TaskType.unknown) ? sig.taskType : intent.taskType;

    // Determine time sensitivity.
    final highTime = intent.deadlineUtc != null || intent.timeHorizon == 'now' || intent.timeHorizon == 'today';
    final timeSensitivity = highTime ? 'high' : (intent.timeHorizon == 'week' ? 'med' : 'low');

    // Determine verifiability.
    String ver = 'none';
    if (effectiveNeedsFacts || effectiveTaskType == TaskType.webFact || effectiveTaskType == TaskType.events) {
      ver = prefs.hatesStaleInfo >= 0.35 ? 'required' : 'preferred';
    }

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
    } else if (ver != 'none') {
      strategy = aiAllowed ? 'local_then_web_then_llm' : 'local_then_web';
      reasons.add('needs_verifiable');
    } else if (aiAllowed) {
      strategy = 'local_then_llm';
      reasons.add('ai_opt_in');
    } else {
      strategy = 'local_then_web';
      reasons.add('ai_off');
    }

    if (highTime) reasons.add('time_pressure');
    if (prefs.hatesVerbose >= 0.35) reasons.add('prefers_short');

    // Budget selection.
    int budget = 450; // default
    if (prefs.lengthDefault == 'tiny') budget = 180;
    if (prefs.lengthDefault == 'short') budget = 320;
    if (prefs.lengthDefault == 'long') budget = 900;

    // Cache TTL.
    int ttl = 3600;
    if (timeSensitivity == 'high') ttl = 900;
    if (effectiveTaskType == TaskType.appHowto) ttl = 86400 * 30;
    if (effectiveTaskType == TaskType.travel) ttl = 86400;
    if (effectiveTaskType == TaskType.events) ttl = 21600;

    final aiProvider = aiAllowed ? 'openai' : 'none';

    return RoutePlan(
      decisionId: id,
      strategy: strategy,
      timeSensitivity: timeSensitivity,
      verifiability: ver,
      aiAllowed: aiAllowed,
      aiProvider: aiProvider,
      budgetTokensMax: budget,
      cacheTtlSeconds: ttl,
      reasonCodes: reasons,
    );
  }
}
