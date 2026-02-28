import 'package:test/test.dart';
import 'package:tempus_victa/services/router/router.dart';
import 'package:tempus_victa/services/consent/consent.dart';
import 'package:tempus_victa/services/redaction/redaction.dart';

void main() {
  group('Router', () {
    test('commits high-confidence candidate', () {
      final store = LocalStore();
      final router = Router(localThreshold: 0.7, store: store);
      final cand = CandidatePlan(
          planId: 'p1',
          intent: 'create_task',
          confidence: 0.86,
          entities: {'title': 'Buy milk'});
      final out = DoctrineOutput(inputId: 'in-1', candidates: [cand]);
      final dec = router.route(out);
      expect(dec.decision, equals('commit'));
      expect(dec.itemId, isNotNull);
      expect(store.items.containsKey(dec.itemId), isTrue);
      expect(
          store.provenance.values.any((p) => p['action'] == 'commit'), isTrue);
    });

    test('escalates low-confidence candidate when consent present', () {
      final store = LocalStore();
      final consent = ConsentManager();
      consent.grant(scope: 'ai:redacted', via: 'test');
      final redactor = Redactor();
      final router = Router(
          localThreshold: 0.7,
          store: store,
          consentManager: consent,
          redactor: redactor);
      final cand = CandidatePlan(
          planId: 'p2',
          intent: 'add_to_list',
          confidence: 0.45,
          entities: {'item': 'dog food'});
      final out = DoctrineOutput(inputId: 'in-2', candidates: [cand]);
      final dec = router.route(out);
      expect(dec.decision, equals('escalate'));
      expect(store.items.isEmpty, isTrue);
      expect(store.provenance.values.any((p) => p['action'] == 'escalate'),
          isTrue);
      // redaction info saved
      expect(
          store.provenance.values.any((p) => p.containsKey('redacted_payload')),
          isTrue);
    });

    test('asks user when low-confidence and no consent', () {
      final store = LocalStore();
      final router = Router(localThreshold: 0.7, store: store);
      final cand = CandidatePlan(
          planId: 'p2b',
          intent: 'add_to_list',
          confidence: 0.45,
          entities: {'item': 'dog food'});
      final out = DoctrineOutput(inputId: 'in-2b', candidates: [cand]);
      final dec = router.route(out);
      expect(dec.decision, equals('ask_user'));
      expect(store.items.isEmpty, isTrue);
      expect(store.provenance.values.any((p) => p['action'] == 'ask_user'),
          isTrue);
    });

    test('urgent priority rule forces commit', () {
      final store = LocalStore();
      final router =
          Router(localThreshold: 0.9, store: store); // high threshold
      final cand = CandidatePlan(
          planId: 'p3',
          intent: 'create_task',
          confidence: 0.4,
          entities: {'title': 'Pay rent', 'priority': 'urgent'});
      final out = DoctrineOutput(inputId: 'in-3', candidates: [cand]);
      final dec = router.route(out);
      expect(dec.decision, equals('commit'));
      expect(store.items.containsKey(dec.itemId), isTrue);
      expect(store.provenance.values.any((p) => p['action'] == 'rule_override'),
          isTrue);
    });
  });
}
