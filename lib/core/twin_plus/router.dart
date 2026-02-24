import 'dart:math';

import 'twin_preference_ledger.dart';
import 'twin_feature_store.dart';

enum TaskType { personalState, appHowto, localSearch, webFact, planning, routing, events, travel, unknown }

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

    // Determine time sensitivity.
    final highTime = intent.deadlineUtc != null || intent.timeHorizon == 'now' || intent.timeHorizon == 'today';
    final timeSensitivity = highTime ? 'high' : (intent.timeHorizon == 'week' ? 'med' : 'low');

    // Determine verifiability.
    String ver = 'none';
    if (intent.needsVerifiableFacts || intent.taskType == TaskType.webFact || intent.taskType == TaskType.events) {
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

    if (intent.taskType == TaskType.appHowto) {
      strategy = 'local_only';
      reasons.add('app_howto');
    } else if (intent.taskType == TaskType.routing) {
      strategy = 'local_then_web';
      reasons.add('routing');
    } else if (intent.taskType == TaskType.events || intent.taskType == TaskType.webFact || intent.taskType == TaskType.travel) {
      strategy = aiAllowed ? 'local_then_web_then_llm' : 'local_then_web';
      reasons.add('verifiable_external');
    } else if (intent.taskType == TaskType.planning) {
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
    if (intent.taskType == TaskType.appHowto) ttl = 86400 * 30;
    if (intent.taskType == TaskType.travel) ttl = 86400;
    if (intent.taskType == TaskType.events) ttl = 21600;

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
