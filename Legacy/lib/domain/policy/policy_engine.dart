// Deterministic Rule Engine (Phase 1.3 stub)
//
// Goal: Provide confidence-gated, non-LLM suggestions from captured text.
// This is intentionally small, boring, and easy to reason about.
//
// Examples:
//  - "milk, eggs, bread" => suggest multiple actions (grocery list)
//  - "tomorrow at 4 call dentist" => suggest action with dueAt
//
// NOTE: This is a stub. We return candidates; UI wiring can be added later.

class RuleSuggestion {
  final String title;
  final DateTime? dueAt;
  final double confidence;
  final String ruleId;

  const RuleSuggestion({
    required this.title,
    required this.ruleId,
    required this.confidence,
    this.dueAt,
  });
}

class PolicyEngine {
  const PolicyEngine();

  // Confidence threshold for surfacing suggestions.
  static const double minConfidence = 0.75;

  List<RuleSuggestion> suggest(String input, {DateTime? now}) {
    final text = input.trim();
    if (text.isEmpty) return const [];
    final n = now ?? DateTime.now();

    final out = <RuleSuggestion>[];

    // Rule: comma-list => multiple items
    // Example: "milk, eggs, bread"
    if (text.contains(',') && text.length <= 160) {
      final parts = text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (parts.length >= 2) {
        for (final p in parts) {
          out.add(RuleSuggestion(
            title: p,
            ruleId: 'comma_list',
            confidence: 0.80,
          ));
        }
        return _gate(out);
      }
    }

    // Rule: very small "tomorrow at HH" parser.
    // Accepts: "tomorrow at 4", "tomorrow at 4pm", "tomorrow 16:30"
    final lower = text.toLowerCase();
    if (lower.contains('tomorrow')) {
      final m = RegExp(r'(?:tomorrow\s*(?:at\s*)?)(\d{1,2})(?::(\d{2}))?\s*(am|pm)?')
          .firstMatch(lower);
      if (m != null) {
        var hour = int.tryParse(m.group(1) ?? '');
        final minute = int.tryParse(m.group(2) ?? '0') ?? 0;
        final ampm = m.group(3);

        if (hour != null && hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
          if (ampm != null) {
            if (ampm == 'pm' && hour < 12) hour += 12;
            if (ampm == 'am' && hour == 12) hour = 0;
          }
          final due = DateTime(n.year, n.month, n.day).add(const Duration(days: 1));
          final dueAt = DateTime(due.year, due.month, due.day, hour, minute);

          // Remove the datetime phrase to form a title suggestion.
          final title = text.replaceAll(m.group(0) ?? '', '').trim();
          out.add(RuleSuggestion(
            title: title.isEmpty ? text : title,
            dueAt: dueAt,
            ruleId: 'tomorrow_time',
            confidence: 0.78,
          ));
          return _gate(out);
        }
      }
    }

    return const [];
  }

  List<RuleSuggestion> _gate(List<RuleSuggestion> inList) {
    return inList.where((s) => s.confidence >= minConfidence).toList(growable: false);
  }
}
