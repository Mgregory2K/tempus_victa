import 'package:test/test.dart';
import 'package:tempus_victa/services/ingestion/ingestion.dart';
import 'package:tempus_victa/services/doctrine/doctrine.dart';
import 'package:tempus_victa/services/router/router.dart';
import 'package:tempus_victa/services/ask_user/ask_user.dart';

void main() {
  group('AskUserManager', () {
    test('accept resolves ask_user and commits item', () async {
      final ti = TextIngestor();
      final input = await ti.ingest('Something ambiguous');
      final out = await Doctrine.parse(input);
      final store = LocalStore();
      final router = Router(
          localThreshold: 0.9,
          store: store); // high threshold to force ask_user
      final dec = router.route(out);
      expect(dec.decision, equals('ask_user'));
      // find prov id
      final prov =
          store.provenance.values.firstWhere((p) => p['action'] == 'ask_user');
      final manager = AskUserManager(store);
      final newProvId = manager.accept(prov['prov_id']);
      expect(newProvId, isNotNull);
      expect(store.items.isNotEmpty, isTrue);
      expect(
          store.provenance.values.any((p) => p['action'] == 'commit_via_user'),
          isTrue);
    });
  });
}
