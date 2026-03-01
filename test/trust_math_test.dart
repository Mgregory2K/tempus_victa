import 'package:flutter_test/flutter_test.dart';
import 'package:tempus_victa/services/trust/trust_math.dart';

void main() {
  test('decay reduces trust', () {
    final v = TrustMath.applyDecay(1.0, 0.5, 2.0); // e^{-1}
    expect(v < 1.0, true);
  });

  test('reinforce increases but clamps', () {
    final r = TrustMath.reinforce(0.9, 0.2);
    expect(r, 1.0);
  });
}
