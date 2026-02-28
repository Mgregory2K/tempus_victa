import '../corkboard_store.dart';
import '../list_intent_parser.dart';
import '../list_store.dart';
import '../project_store.dart';
import '../task_item.dart';
import '../task_store.dart';
import '../twin_plus/twin_event.dart';
import 'routing_counter_store.dart';
import 'routing_decision_store.dart';

/// Shared routing for captures coming from voice/manual surfaces (non-ReadyRoom).
///
/// Doctrine alignment:
/// - Local-only execution (no web, no AI)
/// - Uses learned routing preferences ONLY as a default fallback
/// - Emits TwinEvents for learning signals
///
/// NOTE: This is *not* Ready Room routing. Ready Room remains its own surface.
class CaptureRouter {
  static final CaptureRouter instance = CaptureRouter._();
  CaptureRouter._();

  /// Routes a capture and returns the suggested module to open next.
  ///
  /// [surface] examples: 'bridge_voice', 'tasks_voice', 'manual_capture'
  Future<String> routeCapture({
    required String surface,
    required String transcript,
    required int durationMs,
    String? audioPath,
    required void Function(TwinEvent e) observe,
    String? overrideRouteIntent,
  }) async {
    final text = transcript.trim();
    if (text.isEmpty) return 'tasks';

    // Always learn the capture event (caller may also do this; duplicate is harmless but avoid if you already emit).
    observe(TwinEvent.voiceCaptured(
      surface: surface,
      fieldId: 'capture',
      durationMs: durationMs,
      preview6: TaskItem.titleFromTranscript(text, maxWords: 6),
      chars: text.length,
      words: text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
    ));

    // Multi-intent: split on " and " and execute left-to-right.
    final parts = text
        .split(RegExp(r'\s+and\s+', caseSensitive: false))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    String lastModule = 'tasks';

    for (final p in parts) {
      final lower = p.toLowerCase();

      // --- Navigation (deterministic) ---
      // Examples:
      // - "go to corkboard" / "open bridge" / "show signal bay"
      final nav = RegExp(r'(?i)^(go\s+to|open|show)\s+(.+)$').firstMatch(p);
      if (nav != null) {
        final target = (nav.group(2) ?? '').trim().toLowerCase();
        final m = _moduleFromSpokenTarget(target);
        if (m != null) {
          observe(TwinEvent.actionPerformed(
            surface: surface,
            action: 'nav_capture',
            entityType: 'module',
            meta: {'target': m},
          ));
          lastModule = m;
          continue;
        }
      }

      // --- Tasks (deterministic) ---
      // "create a task ..." / "create task ..." / "task: ..."
      final taskCmd = RegExp(r'(?i)^(create\s+(a\s+)?)?task\b\s*:?\s*(.*)$').firstMatch(p);
      if (taskCmd != null) {
        final body = (taskCmd.group(3) ?? '').trim();
        final t = body.isEmpty ? p : body;
        await _createTask(surface: surface, observe: observe, transcript: t, audioPath: audioPath, audioDurationMs: durationMs);
        lastModule = 'tasks';
        continue;
      }

      // --- Lists (deterministic) ---
      final li = ListIntentParser.parse(p);
      if (li != null) {
        if (li.action == 'create') {
          await ListStore.createIfMissing(li.listName);
          if (li.items.isNotEmpty) {
            await ListStore.addItems(li.listName, li.items);
          }
          observe(TwinEvent.actionPerformed(
            surface: surface,
            action: 'list_created_capture',
            entityType: 'list',
            meta: {'name': li.listName, 'items': li.items.length},
          ));
          lastModule = 'lists';
          continue;
        }
        if (li.action == 'add') {
          await ListStore.addItems(li.listName, li.items);
          observe(TwinEvent.actionPerformed(
            surface: surface,
            action: 'list_items_added_capture',
            entityType: 'list',
            meta: {'name': li.listName, 'items': li.items.length},
          ));
          lastModule = 'lists';
          continue;
        }
        if (li.action == 'remove') {
          await ListStore.removeItems(li.listName, li.items);
          observe(TwinEvent.actionPerformed(
            surface: surface,
            action: 'list_items_removed_capture',
            entityType: 'list',
            meta: {'name': li.listName, 'items': li.items.length},
          ));
          lastModule = 'lists';
          continue;
        }
        if (li.action == 'clear') {
          await ListStore.clear(li.listName);
          observe(TwinEvent.actionPerformed(
            surface: surface,
            action: 'list_cleared_capture',
            entityType: 'list',
            meta: {'name': li.listName},
          ));
          lastModule = 'lists';
          continue;
        }
        if (li.action == 'show') {
          observe(TwinEvent.actionPerformed(
            surface: surface,
            action: 'list_opened_capture',
            entityType: 'list',
            meta: {'name': li.listName},
          ));
          lastModule = 'lists';
          continue;
        }
      }

      // --- Corkboard ---
      if (lower.contains('cork it') || lower.contains('corkboard')) {
        final cleaned = p
            .replaceAll(RegExp(r'(?i)\bcork\s*it\b'), '')
            .replaceAll(RegExp(r'(?i)\bcorkboard\b'), '')
            .trim();
        final ct = cleaned.isEmpty ? p : cleaned;
        await CorkboardStore.addText(ct);
        observe(TwinEvent.actionPerformed(
          surface: surface,
          action: 'cork_created_capture',
          entityType: 'cork',
          meta: {'textLen': ct.length},
        ));
        lastModule = 'corkboard';
        continue;
      }

      // --- Project ---
      final pm = RegExp(r'(?i)^create\s+project\s+(.+)$').firstMatch(p);
      if (pm != null) {
        final name = (pm.group(1) ?? '').trim();
        if (name.isNotEmpty) {
          final proj = await ProjectStore.addProject(name);
          observe(TwinEvent.actionPerformed(
            surface: surface,
            action: 'project_created_capture',
            entityType: 'project',
            entityId: proj.id,
          ));
          lastModule = 'projects';
          continue;
        }
      }

      // --- Reminder (future) ---
      if (lower.contains('remind') || lower.contains('reminder')) {
      await _createTask(surface: surface, observe: observe, transcript: '[REMINDER REQUEST] $p', audioPath: audioPath, audioDurationMs: durationMs);
        lastModule = 'tasks';
        continue;
      }

      // --- Default route (learned or user-picked during training) ---
      final String routeIntent = overrideRouteIntent ?? await _learnedDefaultRouteForSurface(surface);

      // If user explicitly picked a route (training window), record it.
      if (overrideRouteIntent != null) {
        await RoutingCounterStore.instance.recordRouteDecision(surface, overrideRouteIntent);
        observe(TwinEvent.actionPerformed(
          surface: surface,
          action: 'route_decision_capture',
          entityType: 'route',
          meta: {'routeIntent': overrideRouteIntent},
        ));
      }

      if (routeIntent == RoutingCounterStore.intentRouteToCorkboard) {
        await CorkboardStore.addText(p);
        observe(TwinEvent.actionPerformed(
          surface: surface,
          action: 'cork_created_capture_learned_default',
          entityType: 'cork',
          meta: {'textLen': p.length},
        ));
        lastModule = 'corkboard';
        continue;
      }

      // fallback to Task
      await _createTask(surface: surface, observe: observe, transcript: p, audioPath: audioPath, audioDurationMs: durationMs);
      lastModule = 'tasks';
    }

    return lastModule;
  }

  Future<void> _createTask({
    required String surface,
    required void Function(TwinEvent e) observe,
    required String transcript,
    String? audioPath,
    int? audioDurationMs,
  }) async {
    final now = DateTime.now();
    final full = transcript.trim();
    final task = TaskItem(
      id: now.microsecondsSinceEpoch.toString(),
      createdAt: now,
      title: TaskItem.titleFromTranscript(full, maxWords: 6),
      transcript: full,
      audioPath: audioPath,
      audioDurationMs: audioDurationMs,
      projectId: null,
    );

    final tasks = await TaskStore.load();
    await TaskStore.save([task, ...tasks]);

    observe(TwinEvent.actionPerformed(surface: surface, action: 'task_created_capture', entityType: 'task', entityId: task.id));
  }

  Future<String> _learnedDefaultRouteForSurface(String surface) async {
    // Ensure stores are initialized (safe to call repeatedly).
    await RoutingCounterStore.instance.initialize();
    await RoutingDecisionStore.instance.refresh();

    // Priority:
    // 1) If this surface has learned weights in audit stream, use that.
    final direct = RoutingDecisionStore.instance.learnedRouteForSurface(surface, fallbackRouteIntent: '');
    if (direct.isNotEmpty) return direct;

    // 2) Reuse Signal Bay training as the global default, if present.
    final fromSignals = RoutingDecisionStore.instance.learnedRouteForSurface('signal_bay', fallbackRouteIntent: '');
    if (fromSignals.isNotEmpty) return fromSignals;

    // 3) Counter store fallback (per-surface) if any counters exist.
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
