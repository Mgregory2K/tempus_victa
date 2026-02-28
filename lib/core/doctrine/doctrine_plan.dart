class DoctrinePlanStep {
  /// e.g. local|trusted|web|ai
  final String layer;

  /// e.g. resolve_local|rank_sources|search_web|answer_ai
  final String action;

  /// Optional note for dev/audit surfaces (never shown to users unless Dev Mode).
  final String? note;

  const DoctrinePlanStep({
    required this.layer,
    required this.action,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'layer': layer,
        'action': action,
        if (note != null) 'note': note,
      };

  static DoctrinePlanStep fromJson(Map<String, dynamic> j) => DoctrinePlanStep(
        layer: (j['layer'] ?? '').toString(),
        action: (j['action'] ?? '').toString(),
        note: j['note']?.toString(),
      );
}

class DoctrinePlan {
  final String decisionId;
  final List<DoctrinePlanStep> steps;

  const DoctrinePlan({
    required this.decisionId,
    required this.steps,
  });

  Map<String, dynamic> toJson() => {
        'decisionId': decisionId,
        'steps': steps.map((s) => s.toJson()).toList(),
      };

  static DoctrinePlan fromJson(Map<String, dynamic> j) => DoctrinePlan(
        decisionId: (j['decisionId'] ?? '').toString(),
        steps: (j['steps'] is List)
            ? (j['steps'] as List)
                .whereType<Map>()
                .map((m) => DoctrinePlanStep.fromJson(m.cast<String, dynamic>()))
                .toList()
            : const <DoctrinePlanStep>[],
      );
}
