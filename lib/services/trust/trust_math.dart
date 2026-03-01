import 'dart:math' as math;

class TrustMath {
  // Exponential decay: newTrust = current * e^{-lambda * deltaHours}
  static double applyDecay(double current, double lambdaPerHour, double hours) {
    if (current <= 0) return 0.0;
    final decayed = current * math.exp(-lambdaPerHour * hours);
    return decayed.clamp(0.0, 1.0);
  }

  // Reinforcement: add a delta then clamp within [0,1]
  static double reinforce(double current, double delta) {
    final v = current + delta;
    if (v.isNaN) return current;
    return v.clamp(0.0, 1.0);
  }

}


