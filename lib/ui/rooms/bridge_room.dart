import 'package:flutter/material.dart';

import '../../core/app_state_scope.dart';
import '../../core/corkboard_store.dart';
import '../../core/metrics_store.dart';
import '../../core/list_intent_parser.dart';
import '../../core/list_store.dart';
import '../../core/project_store.dart';
import '../../core/task_item.dart';
import '../../core/task_store.dart';
import '../../core/twin_plus/twin_event.dart';
import '../../core/twin_plus/twin_plus_scope.dart';
import '../../core/capture_executor.dart';
import '../../core/doctrine/routing_counter_store.dart';
import '../widgets/route_this_sheet.dart';
import '../../services/voice/voice_service.dart';
import '../room_frame.dart';

class BridgeRoom extends StatefulWidget {
  final String roomName;
  const BridgeRoom({super.key, required this.roomName});

  @override
  State<BridgeRoom> createState() => _BridgeRoomState();
}

class _BridgeRoomState extends State<BridgeRoom> {
  bool _voiceReady = false;
  bool _listening = false;
  String _live = '';

  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  Future<void> _initVoice() async {
    final ok = await VoiceService.instance.init();
    if (!mounted) return;
    setState(() => _voiceReady = ok);
  }

  Future<void> _startListen() async {
    if (!_voiceReady) return;
    setState(() {
      _listening = true;
      _live = '';
    });

    final started = await VoiceService.instance.start(
      onPartial: (p) {
        if (!mounted) return;
        setState(() => _live = p);
      },
    );

    if (!started && mounted) {
      setState(() => _listening = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voice capture failed to start.')));
    }
  }

  Future<void> _stopAndRoute() async {
    if (!_listening) return;
    final res = await VoiceService.instance.stop(finalTranscript: _live);
    if (!mounted) return;

    setState(() => _listening = false);

    final transcript = res.transcript.trim();
    if (transcript.isEmpty) return;

    // 1) Always learn the capture event.
    final kernel = TwinPlusScope.of(context);
    kernel.observe(
      TwinEvent.voiceCaptured(
        surface: 'bridge',
        fieldId: 'bridge_mic',
        durationMs: res.durationMs,
        preview6: res.preview6,
        chars: transcript.length,
        words: transcript.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
      ),
    );

    // 2) Route commands (local-only; deterministic first, learned default last).
    // During the training window, ask the user *once* where this should go.
    const surfaceKey = 'bridge_voice';
    String? overrideIntent;

    final isMulti = transcript.contains(RegExp(r'\s+and\s+', caseSensitive: false));
    if (!isMulti && RoutingCounterStore.instance.isTrainingWindow(surfaceKey)) {
      overrideIntent = await RouteThisSheet.show(
        context,
        title: 'Route this capture (training)',
        choices: const [
          RouteChoice(label: 'Task', value: RoutingCounterStore.intentRouteToTask, icon: Icons.task_alt_rounded),
          RouteChoice(label: 'Corkboard', value: RoutingCounterStore.intentRouteToCorkboard, icon: Icons.push_pin_rounded),
        ],
      );
    }

    final exec = await CaptureExecutor.instance.executeVoiceCapture(
      surface: surfaceKey,
      transcript: transcript,
      durationMs: res.durationMs,
      audioPath: res.audioPath,
      observe: (e) => kernel.observe(e),
      overrideRouteIntent: overrideIntent,
    );

    if (overrideIntent != null && mounted) {
      final label = overrideIntent == RoutingCounterStore.intentRouteToCorkboard ? 'Corkboard' : 'Task';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Routed (training): $label')));
    }

    // 3) Default UX: jump to the most relevant module.: jump to the most relevant module.
    if (!mounted) return;
    AppStateScope.of(context).setSelectedModule(exec.nextModule);
  }

  Future<String> _routeTranscript(dynamic kernel, String transcript, int durationMs) async {
    // Support simple multi-intent: split on " and " and execute left-to-right.
    final parts = transcript.split(RegExp(r'\s+and\s+', caseSensitive: false)).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    String lastModule = 'tasks';

    for (final p in parts) {
      final lower = p.toLowerCase();

      // --- Lists (deterministic) ---
      final li = ListIntentParser.parse(p);
      if (li != null) {
        if (li.action == 'create') {
          await ListStore.createIfMissing(li.listName);
          if (li.items.isNotEmpty) {
            await ListStore.addItems(li.listName, li.items);
          }
          kernel.observe(
            TwinEvent.actionPerformed(surface: 'bridge', action: 'list_created_voice', entityType: 'list', meta: {'name': li.listName, 'items': li.items.length}),
          );
          lastModule = 'lists';
          continue;
        }
        if (li.action == 'add') {
          await ListStore.addItems(li.listName, li.items);
          kernel.observe(
            TwinEvent.actionPerformed(surface: 'bridge', action: 'list_items_added_voice', entityType: 'list', meta: {'name': li.listName, 'items': li.items.length}),
          );
          lastModule = 'lists';
          continue;
        }
        if (li.action == 'remove') {
          await ListStore.removeItems(li.listName, li.items);
          kernel.observe(
            TwinEvent.actionPerformed(surface: 'bridge', action: 'list_items_removed_voice', entityType: 'list', meta: {'name': li.listName, 'items': li.items.length}),
          );
          lastModule = 'lists';
          continue;
        }
        if (li.action == 'clear') {
          await ListStore.clear(li.listName);
          kernel.observe(
            TwinEvent.actionPerformed(surface: 'bridge', action: 'list_cleared_voice', entityType: 'list', meta: {'name': li.listName}),
          );
          lastModule = 'lists';
          continue;
        }
        if (li.action == 'show') {
          kernel.observe(
            TwinEvent.actionPerformed(surface: 'bridge', action: 'list_opened_voice', entityType: 'list', meta: {'name': li.listName}),
          );
          lastModule = 'lists';
          continue;
        }
      }


      // --- Corkboard ---
      // "cork it <text>" OR "<text> cork it"
      if (lower.contains('cork it') || lower.contains('corkboard')) {
        final cleaned = p
            .replaceAll(RegExp(r'(?i)\bcork\s*it\b'), '')
            .replaceAll(RegExp(r'(?i)\bcorkboard\b'), '')
            .trim();
        final text = cleaned.isEmpty ? transcript : cleaned;
        await CorkboardStore.addText(text);
        kernel.observe(
          TwinEvent.actionPerformed(surface: 'bridge', action: 'cork_created_voice', entityType: 'cork', meta: {'textLen': text.length}),
        );
        lastModule = 'corkboard';
        continue;
      }

      // --- Project ---
      // "create project <name>"
      final pm = RegExp(r'(?i)^create\s+project\s+(.+)\$').firstMatch(p);
      if (pm != null) {
        final name = (pm.group(1) ?? '').trim();
        if (name.isNotEmpty) {
          final proj = await ProjectStore.addProject(name);
          kernel.observe(
            TwinEvent.actionPerformed(surface: 'bridge', action: 'project_created_voice', entityType: 'project', entityId: proj.id),
          );
          lastModule = 'projects';
          continue;
        }
      }

      // --- Reminder (future) ---
      // No reminder scheduler in-app yet. Preserve intent in transcript.
      if (lower.contains('remind') || lower.contains('reminder')) {
        await _createTask(kernel, p, durationMs, tagPrefix: '[REMINDER REQUEST] ');
        lastModule = 'tasks';
        continue;
      }

      // --- Default: Task ---
      await _createTask(kernel, p, durationMs);
      lastModule = 'tasks';
    }

    return lastModule;
  }

  Future<void> _createTask(
    dynamic kernel,
    String transcript,
    int durationMs, {
    String tagPrefix = '',
  }) async {
    final now = DateTime.now();
    final full = (tagPrefix + transcript).trim();

    final task = TaskItem(
      id: now.microsecondsSinceEpoch.toString(),
      createdAt: now,
      title: TaskItem.titleFromTranscript(transcript, maxWords: 6),
      transcript: full, // ✅ retain FULL transcript for later editing
      audioDurationMs: durationMs,
      audioPath: null,
      projectId: null,
    );

    final tasks = await TaskStore.load();
    await TaskStore.save([task, ...tasks]);
    AppStateScope.of(context).bumpTasksVersion();

    await MetricsStore.inc(TvMetrics.tasksCreatedVoice);

    kernel.observe(
      TwinEvent.actionPerformed(surface: 'bridge', action: 'task_created_voice', entityType: 'task', entityId: task.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return RoomFrame(
      title: widget.roomName,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Welcome back.', style: tt.titleLarge),
            const SizedBox(height: 12),

            // Quick capture card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_listening ? 'Listening…' : 'Quick voice task', style: tt.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      _live.trim().isEmpty ? 'Tap the mic and speak.' : _live.trim(),
                      style: tt.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: !_voiceReady ? null : (_listening ? _stopAndRoute : _startListen),
                            icon: Icon(_listening ? Icons.stop : Icons.mic),
                            label: Text(_listening ? 'Stop + Create' : 'Voice'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Placeholder dashboard sections (kept intentionally light; real redesign uses the concept PNGs).
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today\'s Focus', style: tt.titleMedium),
                    const SizedBox(height: 8),
                    Text('Bridge dashboard UI will be redesigned to match the concept images.', style: tt.bodySmall),
                  ],
                ),
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}
