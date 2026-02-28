import 'package:tempus_victa/services/router/router.dart';
import 'package:tempus_victa/services/consent/consent.dart';
import 'package:tempus_victa/services/redaction/redaction.dart';

void main() {
  print('--- debug: high-confidence commit');
  final store1 = LocalStore();
  final router1 = Router(localThreshold: 0.7, store: store1);
  final cand1 = CandidatePlan(
      planId: 'p1',
      intent: 'create_task',
      confidence: 0.86,
      entities: {'title': 'Buy milk'});
  final out1 = DoctrineOutput(inputId: 'in-1', candidates: [cand1]);
  final dec1 = router1.route(out1);
  print('decision: ${dec1.decision}, itemId: ${dec1.itemId}');
  print('store1 items empty? ${store1.items.isEmpty}');
  print(
      'store1 provenance actions: ${store1.provenance.values.map((p) => p["action"]).toList()}');

  print('\n--- debug: escalate when consent present');
  final store2 = LocalStore();
  final consent = ConsentManager();
  consent.grant(scope: 'ai:redacted', via: 'debug');
  final redactor = Redactor();
  final router2 = Router(
      localThreshold: 0.7,
      store: store2,
      consentManager: consent,
      redactor: redactor);
  final cand2 = CandidatePlan(
      planId: 'p2',
      intent: 'add_to_list',
      confidence: 0.45,
      entities: {'item': 'dog food'});
  final out2 = DoctrineOutput(inputId: 'in-2', candidates: [cand2]);
  final dec2 = router2.route(out2);
  print('decision: ${dec2.decision}, reason: ${dec2.reason}');
  print('store2 items empty? ${store2.items.isEmpty}');
  print(
      'store2 provenance actions: ${store2.provenance.values.map((p) => p["action"]).toList()}');
  print(
      'store2 provenance redacted_payload present? ${store2.provenance.values.any((p) => p.containsKey('redacted_payload'))}');

  print('\n--- debug: ask user when no consent');
  final store3 = LocalStore();
  final router3 = Router(localThreshold: 0.7, store: store3);
  final cand3 = CandidatePlan(
      planId: 'p2b',
      intent: 'add_to_list',
      confidence: 0.45,
      entities: {'item': 'dog food'});
  final out3 = DoctrineOutput(inputId: 'in-2b', candidates: [cand3]);
  final dec3 = router3.route(out3);
  print('decision: ${dec3.decision}, reason: ${dec3.reason}');
  print('store3 items empty? ${store3.items.isEmpty}');
  print(
      'store3 provenance actions: ${store3.provenance.values.map((p) => p["action"]).toList()}');
}
