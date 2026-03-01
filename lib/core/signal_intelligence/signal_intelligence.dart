import 'dart:math' as math;

import 'package:tempus_victa/services/trust/trust_math.dart';

import '../signal_item.dart';
import 'signal_feedback_store.dart';

class SignalScore {
  final double value; // 0..1
  final List<String> reasons;

  const SignalScore(this.value, {this.reasons = const []});
}

class SignalIntelligence {
  SignalIntelligence._();

  /// Deterministic score for ordering signals.
  ///
  /// This is intentionally lightweight and explainable:
  /// - Source trust (learned from user actions)
  /// - Actionability (keyword + structure heuristics)
  /// - Reinforcement (fingerprint-specific outcomes)
  /// - Recency
  /// - Repeat count
  static SignalScore score(SignalItem s, SignalFeedbackSnapshot snap,
      {DateTime? now}) {
    final tNow = now ?? DateTime.now();

    final srcStats = snap.statsForSource(s.source);
    final fpStats = snap.statsForFingerprint(s.fingerprint);

    final sourceTrustRaw = _statsToTrust(srcStats);
    final reinforcementRaw = _statsToTrust(fpStats);

    // Apply temporal decay to trust signals using TrustMath. Use ageHours
    // (time since lastSeen) to decay fingerprint reinforcement and source trust
    // so older interactions reduce influence over time.
    final tNowLocal = tNow.toUtc();
    final ageHours = math.max(
      0.0, tNowLocal.difference(s.lastSeenAt.toUtc()).inMinutes / 60.0);
    final decayLambdaPerHour = 0.02; // tunable decay constant
    final sourceTrust =
        TrustMath.applyDecay(sourceTrustRaw, decayLambdaPerHour, ageHours);
    final reinforcement = TrustMath.applyDecay(
        reinforcementRaw, decayLambdaPerHour * 1.5, ageHours);
    final actionability = _actionability(s.title, s.body);
    final recency = math.exp(-ageHours / 48.0).clamp(0.0, 1.0).toDouble();

    final countBoost = (math.log(math.max(1, s.count).toDouble()) / 6.0)
        .clamp(0.0, 0.18)
        .toDouble();

    // Weighted blend. Keep it stable; no single feature dominates.
    var score = (0.35 * sourceTrust) +
        (0.35 * actionability) +
        (0.20 * reinforcement) +
        (0.10 * recency) +
        countBoost;
    score = score.clamp(0.0, 1.0).toDouble();

    final reasons = <String>[];
    if (actionability >= 0.75) reasons.add('actionable');
    if (sourceTrust >= 0.70) reasons.add('trusted_source');
    if (reinforcement >= 0.70) reasons.add('reinforced');
    if (recency >= 0.75) reasons.add('recent');
    if (s.count >= 3) reasons.add('repeated');

    return SignalScore(score, reasons: reasons);
  }

  /// Maps feedback stats into a [0..1] trust scalar.
  ///
  /// Positive actions increase trust:
  /// - promoted (strong)
  /// - opened (weak)
  /// - acknowledged (weak)
  ///
  /// Negative actions decrease trust:
  /// - recycled (medium)
  /// - muted (strong)
  static double _statsToTrust(SignalFeedbackStats st) {
    final raw = (st.promoted * 2.0) +
        (st.opened * 0.25) +
        (st.acknowledged * 0.15) -
        (st.recycled * 0.8) -
        (st.muted * 1.2);

    // Squash to [-1..1] then map to [0..1]
    final squashed = raw / (raw.abs() + 3.0);
    final trust = 0.5 + (0.5 * squashed);
    return trust.clamp(0.0, 1.0).toDouble();
  }

  static double _actionability(String title, String? body) {
    final t = (title).toLowerCase();
    final b = (body ?? '').toLowerCase();
    final all = '$t\n$b';

    double score = 0.20;

    // Strong action cues
    final strong = <String, double>{
      'confirm': 0.35,
      'verification': 0.35,
      'verify': 0.35,
      'action required': 0.40,
      'required': 0.25,
      'payment': 0.25,
      'invoice': 0.22,
      'overdue': 0.35,
      'failed': 0.30,
      'error': 0.28,
      'declined': 0.28,
      'security': 0.25,
      'password': 0.22,
      'code': 0.18,
      'otp': 0.20,
      'reminder': 0.22,
      'appointment': 0.20,
      'meeting': 0.18,
      'due': 0.25,
      'deadline': 0.30,
      'tomorrow': 0.18,
      'today': 0.15,
      'urgent': 0.35,
      'asap': 0.35,
    };

    for (final e in strong.entries) {
      if (all.contains(e.key)) score += e.value;
    }

    // Punctuation / structure cues
    final exclamations = _countChar(all, '!');
    if (exclamations >= 1) score += 0.06;
    if (exclamations >= 3) score += 0.06;

    final hasQuestion = all.contains('?');
    if (hasQuestion) score += 0.04;

    // Very short generic notifications are often noise.
    if (all.trim().length < 12) score -= 0.08;

    // Common low-action spammy patterns
    final noisy = <String>[
      'liked your',
      'reacted to',
      'new follower',
      'suggested for you',
      'trending',
      'recommended',
      'discover',
      'promotion',
    ];
    for (final k in noisy) {
      if (all.contains(k)) score -= 0.15;
    }

    return score.clamp(0.0, 1.0).toDouble();
  }

  static int _countChar(String s, String ch) {
    var c = 0;
    for (var i = 0; i < s.length; i++) {
      if (s[i] == ch) c++;
    }
    return c;
  }
}
