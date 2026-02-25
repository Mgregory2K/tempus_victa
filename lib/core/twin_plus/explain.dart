import 'router.dart';
import 'twin_preference_ledger.dart';

class ExplainRequest {
  final String kind; // routing|shaping
  final String? decisionId;
  const ExplainRequest({required this.kind, this.decisionId});
}

class TwinExplanation {
  final String summary;
  final List<String> reasons;
  const TwinExplanation({required this.summary, required this.reasons});
}

class TwinExplainer {
  final TwinPreferenceLedger prefs;
  TwinExplainer({required this.prefs});

  TwinExplanation explainRouting(RoutePlan plan) {
    final reasons = <String>[
      ...plan.reasonCodes,
      if (prefs.hatesVerbose >= 0.35) 'hates_verbose',
      if (prefs.hatesStaleInfo >= 0.35) 'hates_stale_info',
      if (prefs.justTheFactsActive) 'just_the_facts',
    ];

    // Keep it numeric and incremental (0.0–1.0, 0.1 increments).
    final ts = plan.timeSensitivityW.toStringAsFixed(1);
    final ver = plan.verifiabilityW.toStringAsFixed(1);

    return TwinExplanation(
      summary: 'Strategy: ${plan.strategy}, verifiabilityW: $ver, timeW: $ts',
      reasons: reasons,
    );
  }
}
