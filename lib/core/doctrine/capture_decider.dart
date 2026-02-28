import '../list_intent_parser.dart';
import 'routing_counter_store.dart';
import 'routing_decision_store.dart';

/// Pure decision layer for capture routing.
///
/// Hard Stabilization goal:
/// - NO persistence
/// - NO UI
/// - NO navigation side-effects
/// - Returns a plan the executor can apply
class CaptureDecider {
  static final CaptureDecider instance = CaptureDecider._();
  CaptureDecider._();

  Future<CapturePlan> decide({
    required String surface,
    required String transcript,
    String? overrideRouteIntent,
  }) async {
    final text = transcript.trim();
    if (text.isEmpty) {
      return const CapturePlan(nextModule: 'tasks', ops: <CaptureOp>[]);
    }

    // Multi-intent: ONLY split on explicit sequencing ("then", "and then", or ';').
// Splitting on plain "and" destroys natural speech ("call Jen and ask about...") into garbage tasks.
final parts = text
    .split(RegExp(r'(?:\s+and\s+then\s+|\s+then\s+|;)', caseSensitive: false))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList(growable: false);

    final ops = <CaptureOp>[];
    String lastModule = 'tasks';

    for (final p in parts) {
      final lower = p.toLowerCase();

      // Navigation command: "go to", "open", "show".
      final nav = RegExp(r'(?i)^(go\s+to|open|show)\s+(.+)$').firstMatch(p);
      if (nav != null) {
        final target = (nav.group(2) ?? '').trim().toLowerCase();
        final m = _moduleFromSpokenTarget(target);
        if (m != null) {
          ops.add(CaptureOp(type: CaptureOpType.navModule, data: {'module': m}));
          lastModule = m;
          continue;
        }
      }

      // Task command
      final taskCmd = RegExp(r'(?i)^(create\s+(a\s+)?)?task\b\s*:?\s*(.*)$').firstMatch(p);
      if (taskCmd != null) {
        final body = (taskCmd.group(3) ?? '').trim();
        final t = body.isEmpty ? p : body;
        ops.add(CaptureOp(type: CaptureOpType.createTask, data: {'transcript': t}));
        lastModule = 'tasks';
        continue;
      }

      // Lists
      final li = ListIntentParser.parse(p);
      if (li != null) {
        ops.add(CaptureOp(
          type: CaptureOpType.listIntent,
          data: {
            'action': li.action,
            'listName': li.listName,
            'items': li.items,
          },
        ));
        lastModule = 'lists';
        continue;
      }

      // Corkboard
      if (lower.contains('cork it') || lower.contains('corkboard')) {
        final cleaned = p
            .replaceAll(RegExp(r'(?i)\bcork\s*it\b'), '')
            .replaceAll(RegExp(r'(?i)\bcorkboard\b'), '')
            .trim();
        final ct = cleaned.isEmpty ? p : cleaned;
        ops.add(CaptureOp(type: CaptureOpType.addCork, data: {'text': ct}));
        lastModule = 'corkboard';
        continue;
      }

      // Project
      final pm = RegExp(r'(?i)^create\s+project\s+(.+)$').firstMatch(p);
      if (pm != null) {
        final name = (pm.group(1) ?? '').trim();
        if (name.isNotEmpty) {
          ops.add(CaptureOp(type: CaptureOpType.createProject, data: {'name': name}));
          lastModule = 'projects';
          continue;
        }
      }

      // Reminder -> task
      if (lower.contains('remind') || lower.contains('reminder')) {
        ops.add(CaptureOp(type: CaptureOpType.createTask, data: {'transcript': '[REMINDER REQUEST] $p'}));
        lastModule = 'tasks';
        continue;
      }

      // Default route intent (learned or user override)
      final routeIntent = overrideRouteIntent ?? await _learnedDefaultRouteForSurface(surface);
      if (overrideRouteIntent != null) {
        ops.add(CaptureOp(type: CaptureOpType.recordRouteDecision, data: {'surface': surface, 'routeIntent': overrideRouteIntent}));
      }

      if (routeIntent == RoutingCounterStore.intentRouteToCorkboard) {
        ops.add(CaptureOp(type: CaptureOpType.addCork, data: {'text': p, 'learnedDefault': true}));
        lastModule = 'corkboard';
        continue;
      }

      // fallback task
      ops.add(CaptureOp(type: CaptureOpType.createTask, data: {'transcript': p, 'learnedDefault': true}));
      lastModule = 'tasks';
    }

    return CapturePlan(nextModule: lastModule, ops: ops);
  }

  Future<String> _learnedDefaultRouteForSurface(String surface) async {
    await RoutingCounterStore.instance.initialize();
    await RoutingDecisionStore.instance.refresh();

    final direct = RoutingDecisionStore.instance.learnedRouteForSurface(surface, fallbackRouteIntent: '');
    if (direct.isNotEmpty) return direct;

    final fromSignals = RoutingDecisionStore.instance.learnedRouteForSurface('signal_bay', fallbackRouteIntent: '');
    if (fromSignals.isNotEmpty) return fromSignals;

    return RoutingCounterStore.instance.learnedDefaultRoute(surface);
  }

  String? _moduleFromSpokenTarget(String target) {
    final t = target.replaceAll(RegExp(r'[^a-z\s]'), '').trim();
    if (t.isEmpty) return null;
    if (t.contains('bridge')) return 'bridge';
    if (t.contains('ready room')) return 'ready_room';
    if (t.contains('signal')) return 'signal_bay';
    if (t.contains('cork')) return 'corkboard';
    if (t.contains('task')) return 'tasks';
    if (t.contains('project')) return 'projects';
    if (t.contains('quote')) return 'quote_board';
    if (t.contains('recycle')) return 'recycle_bin';
    if (t.contains('list')) return 'lists';
    return null;
  }
}

class CapturePlan {
  final String nextModule;
  final List<CaptureOp> ops;
  const CapturePlan({required this.nextModule, required this.ops});
}

enum CaptureOpType {
  navModule,
  createTask,
  listIntent,
  addCork,
  createProject,
  recordRouteDecision,
}

class CaptureOp {
  final CaptureOpType type;
  final Map<String, dynamic> data;
  const CaptureOp({required this.type, required this.data});
}
