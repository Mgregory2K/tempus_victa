import '../list_intent_parser.dart';
import '../task_item.dart';
import 'execution_plan.dart';

class IntentRouter {
  static ExecutionPlan route({
    required String surface,
    required String rawText,
    Map<String, dynamic>? metadata,
  }) {
    final text = rawText.trim();
    if (text.isEmpty) {
      return ExecutionPlan(surface: surface, rawText: rawText, actions: const [], confidence: 0.0);
    }

    // 1) Lists (deterministic)
    final li = ListIntentParser.parse(text);
    if (li != null) {
      final actions = <DoctrineAction>[];
      final listName = li.listName.trim();
      if (listName.isNotEmpty) {
        actions.add(CreateListIfMissingAction(listName));
      }
      if (li.action == 'add' && li.items.isNotEmpty) {
        actions.add(AddListItemsAction(listName: listName, items: li.items));
      } else if (li.action == 'remove' && li.items.isNotEmpty) {
        actions.add(RemoveListItemsAction(listName: listName, items: li.items));
      } else if (li.action == 'clear') {
        actions.add(ClearListAction(listName));
      } else if (li.action == 'create' && li.items.isNotEmpty) {
        actions.add(AddListItemsAction(listName: listName, items: li.items));
      }
      return ExecutionPlan(surface: surface, rawText: rawText, actions: actions, confidence: 0.85);
    }

    final lower = text.toLowerCase();

    // 2) Corkboard: contains "cork it"
    if (lower.contains('cork it') || lower.contains('corkboard')) {
      final cleaned = text
          .replaceAll(RegExp(r'(?i)\bcork\s*it\b'), '')
          .replaceAll(RegExp(r'(?i)\bcorkboard\b'), '')
          .trim();
      final payload = cleaned.isEmpty ? text : cleaned;
      return ExecutionPlan(
        surface: surface,
        rawText: rawText,
        actions: [CorkItAction(payload)],
        confidence: 0.7,
      );
    }

    // 3) Create project
    final pm = RegExp(r'(?i)^create\s+project\s+(.+)\$').firstMatch(text);
    if (pm != null) {
      final name = (pm.group(1) ?? '').trim();
      if (name.isNotEmpty) {
        return ExecutionPlan(
          surface: surface,
          rawText: rawText,
          actions: [CreateProjectAction(name)],
          confidence: 0.7,
        );
      }
    }

    // 4) Default: create task (title=~6 words, full transcript retained)
    final title = TaskItem.titleFromTranscript(text, maxWords: 6);
    final durationMs = metadata?['durationMs'] is int ? metadata!['durationMs'] as int : null;
    return ExecutionPlan(
      surface: surface,
      rawText: rawText,
      actions: [
        CreateTaskAction(title: title, transcript: text, audioDurationMs: durationMs),
      ],
      confidence: 0.6,
    );
  }
}
