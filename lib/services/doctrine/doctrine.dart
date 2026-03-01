import '../ingestion/ingestion.dart';
import '../router/router.dart';

/// Very small rule-based parser to produce CandidatePlans from DoctrineInput.
class Doctrine {
  static Future<DoctrineOutput> parse(DoctrineInput input) async {
    final text = input.normalizedText.toLowerCase();
    final candidates = <CandidatePlan>[];

    if (text.contains('buy') ||
        text.contains('shopping') ||
        text.contains('add to list')) {
      candidates.add(CandidatePlan(
        planId: 'plan-buy-1',
        intent: 'create_task',
        confidence: 0.85,
        entities: {'title': text.replaceAll(RegExp(r'[^\w\s]'), '')},
      ));
    } else if (text.contains('remind') || text.contains('reminder')) {
      candidates.add(CandidatePlan(
        planId: 'plan-remind-1',
        intent: 'set_reminder',
        confidence: 0.8,
        entities: {'title': text},
      ));
    } else {
      // low confidence fallback
      candidates.add(CandidatePlan(
        planId: 'plan-unknown-1',
        intent: 'unknown',
        confidence: 0.4,
        entities: {'text': text},
      ));
    }

    return DoctrineOutput(inputId: input.inputId, candidates: candidates);
  }
}
