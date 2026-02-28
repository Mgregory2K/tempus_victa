import 'package:test/test.dart';
import 'package:tempus_victa/services/twin/twin.dart';

void main() {
  group('TwinModel', () {
    test('initial weight is zero and updates apply learningRate', () {
      final m = TwinModel(learningRate: 0.5);
      expect(m.getWeight('signal:accept'), equals(0.0));
      final after = m.updateWeight('signal:accept', 2.0);
      // delta 2.0 * lr 0.5 = 1.0
      expect(after, equals(1.0));
      expect(m.getWeight('signal:accept'), equals(1.0));
    });

    test('processSignal logs and updates mapped weights', () {
      final m = TwinModel(learningRate: 1.0);
      final s =
          TwinSignal(signalId: 's1', signalType: 'accept', itemId: 'item-1');
      m.processSignal(s);
      expect(m.getWeight('signal:accept'), greaterThan(0.0));
      expect(m.log.length, equals(1));
    });

    test('feature-based update for urgent priority', () {
      final m = TwinModel(learningRate: 1.0);
      final s = TwinSignal(
          signalId: 's2',
          signalType: 'click',
          features: {'priority': 'urgent'});
      m.processSignal(s);
      expect(m.getWeight('signal:click'), equals(0.2));
      expect(m.getWeight('feature:priority:urgent'), equals(0.5));
    });
  });
}
