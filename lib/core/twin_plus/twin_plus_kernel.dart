import '../profile/user_profile_store.dart';
import 'router.dart';
import 'shaper.dart';
import 'twin_event.dart';
import 'twin_event_ledger.dart';
import 'twin_feature_store.dart';
import 'twin_preference_ledger.dart';
import 'explain.dart';

class TwinSnapshot {
  final Map<String, dynamic> prefs;
  final Map<String, dynamic> features;
  final List<TwinEvent> recentEvents;

  const TwinSnapshot({
    required this.prefs,
    required this.features,
    required this.recentEvents,
  });
}

class TwinPlusKernel {
  TwinPlusKernel._();
  static final TwinPlusKernel instance = TwinPlusKernel._();

  late final TwinEventLedger ledger;
  late final TwinPreferenceLedger prefs;
  late final TwinFeatureStore features;
  late final TwinRouter router;
  late final TwinShaper shaper;
  late final TwinExplainer explainer;

  bool _ready = false;
  bool get isReady => _ready;

  Future<void> init() async {
    ledger = await TwinEventLedger.open();
    prefs = await TwinPreferenceLedger.open();
    features = await TwinFeatureStore.open(prefs: prefs);
    router = TwinRouter(prefs: prefs, features: features);
    shaper = TwinShaper(prefs: prefs, features: features);
    explainer = TwinExplainer(prefs: prefs);

    await ledger.append(TwinEvent.appStarted());
    await UserProfileStore.ensureSeeded();
    observe(TwinEvent.actionPerformed(surface: 'profile', actor: TwinActor.system, action: 'user_profile_seeded'));

    _ready = true;
  }

  void observe(TwinEvent e) {
    // Fire-and-forget. Day-one volumes are small; flush in ledger.
    ledger.append(e);
    features.apply(e);
  }

  RoutePlan route(QueryIntent intent) {
    final plan = router.route(intent);
    observe(TwinEvent(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      tsUtc: DateTime.now().toUtc(),
      surface: intent.surface,
      type: TwinEventType.routeChosen,
      actor: TwinActor.system,
      payload: {
        'decisionId': plan.decisionId,
        'strategy': plan.strategy,
        'timeSensitivity': plan.timeSensitivity,
        'verifiability': plan.verifiability,
        'aiAllowed': plan.aiAllowed,
        'aiProvider': plan.aiProvider,
        'budgetTokensMax': plan.budgetTokensMax,
        'cacheTtlSeconds': plan.cacheTtlSeconds,
        'reasonCodes': plan.reasonCodes,
      },
    ));
    return plan;
  }

  ShapedOutput shape(OutputIntent intent) {
    final out = shaper.shape(intent);
    observe(TwinEvent(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      tsUtc: DateTime.now().toUtc(),
      surface: intent.surface,
      type: TwinEventType.outputShaped,
      actor: TwinActor.system,
      payload: {
        'appliedLength': out.appliedLength,
        'appliedFormat': out.appliedFormat,
        'chars': out.text.length,
      },
      confidence: 0.95,
    ));
    return out;
  }

  TwinExplanation explainRouting(RoutePlan plan) => explainer.explainRouting(plan);

  TwinSnapshot snapshot() => TwinSnapshot(
        prefs: prefs.snapshot(),
        features: features.snapshot(),
        recentEvents: ledger.query(limit: 50),
      );
}
