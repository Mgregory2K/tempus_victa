import 'package:test/test.dart';
import 'package:tempus_victa/services/ingestion/ingestion.dart';
import 'package:tempus_victa/services/doctrine/doctrine.dart';
import 'package:tempus_victa/services/router/router.dart';
import 'package:tempus_victa/services/consent/consent.dart';
import 'package:tempus_victa/services/redaction/redaction.dart';

void main() {
  group('Integration: ingest -> doctrine -> router', () {
    test('high-confidence ingestion commits locally', () async {
      final ti = TextIngestor();
      final input = await ti.ingest('Buy dog food tomorrow');
      final out = await Doctrine.parse(input);
      final store = LocalStore();
      final router = Router(localThreshold: 0.7, store: store);
      final dec = router.route(out);
      expect(dec.decision, equals('commit'));
      expect(dec.itemId, isNotNull);
      expect(store.items.containsKey(dec.itemId), isTrue);
    });

    test('low-confidence ingestion escalates when consent + internet allowed',
        () async {
      final ti = TextIngestor();
      final input = await ti.ingest('Some ambiguous phrase');
      final out = await Doctrine.parse(input);
      final store = LocalStore();
      final consent = ConsentManager(storagePath: 'build/test_consent.json');
      consent.grant(scope: 'ai:redacted', via: 'test');
      final redactor = Redactor();
      final router = Router(
          localThreshold: 0.7,
          store: store,
          consentManager: consent,
          redactor: redactor,
          policy: Policy(internetAllowed: true));
      final dec = router.route(out);
      expect(dec.decision, equals('escalate'));
      expect(store.provenance.values.any((p) => p['action'] == 'escalate'),
          isTrue);
    });

    test('low-confidence ingestion asks user when internet disallowed',
        () async {
      final ti = TextIngestor();
      final input = await ti.ingest('Another ambiguous phrase');
      final out = await Doctrine.parse(input);
      final store = LocalStore();
      final consent = ConsentManager(storagePath: 'build/test_consent2.json');
      consent.grant(scope: 'ai:redacted', via: 'test');
      final redactor = Redactor();
      final router = Router(
          localThreshold: 0.7,
          store: store,
          consentManager: consent,
          redactor: redactor,
          policy: Policy(internetAllowed: false));
      final dec = router.route(out);
      expect(dec.decision, equals('ask_user'));
      expect(
          store.provenance.values.any((p) => p['action'] == 'internet_blocked'),
          isTrue);
    });
  });
}
