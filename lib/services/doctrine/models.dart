class CandidatePlan {
  final String planId;
  final String intent;
  final double confidence;
  final Map<String, dynamic> entities;
  final List<Map<String, dynamic>> actions;
  final List<String> explain;
  final String? provenanceRef;

  CandidatePlan({
    required this.planId,
    required this.intent,
    required this.confidence,
    Map<String, dynamic>? entities,
    List<Map<String, dynamic>>? actions,
    List<String>? explain,
    this.provenanceRef,
  })  : entities = entities ?? {},
        actions = actions ?? [],
        explain = explain ?? [];
}

class DoctrineOutput {
  final String inputId;
  final List<CandidatePlan> candidates;

  DoctrineOutput({required this.inputId, List<CandidatePlan>? candidates})
      : candidates = candidates ?? [];
}
