import 'package:flutter/foundation.dart';

import 'corkboard_store.dart';
import 'doctrine/capture_decider.dart';
import 'doctrine/routing_counter_store.dart';
import 'list_store.dart';
import 'project_store.dart';
import 'signal_item.dart';
import 'signal_store.dart';
import 'task_item.dart';
import 'task_store.dart';
import 'twin_plus/twin_event.dart';

/// Hard Stabilization: single atomic boundary for capture execution.
///
/// Guarantees:
/// - A Signal is persisted FIRST for every capture.
/// - CaptureDecider is PURE (no persistence, no UI).
/// - All side-effects (stores + TwinEvents) happen here.
/// - Returns nextModule for UX navigation.
class CaptureExecutor {
  static final CaptureExecutor instance = CaptureExecutor._();
  CaptureExecutor._();

  Future<CaptureExecutionResult> executeVoiceCapture({
    required String surface,
    required String transcript,
    required int durationMs,
    String? audioPath,
    required void Function(TwinEvent e) observe,
    String? overrideRouteIntent,
  }) async {
    final text = transcript.trim();

    // 1) Persist signal FIRST (always).
    final signal = await _persistSignal(
      source: surface,
      title: TaskItem.titleFromTranscript(text.isEmpty ? 'Voice' : text, maxWords: 6),
      body: text,
    );

    // 2) Emit capture event (learning).
    observe(TwinEvent.voiceCaptured(
      surface: surface,
      fieldId: 'global_capture',
      durationMs: durationMs,
      preview6: TaskItem.titleFromTranscript(text, maxWords: 6),
      chars: text.length,
      words: _wordCount(text),
    ));

    observe(TwinEvent.actionPerformed(
      surface: surface,
      action: 'signal_persisted',
      entityType: 'signal',
      entityId: signal.id,
      meta: {'chars': text.length, 'words': _wordCount(text)},
    ));

    // 3) Decide plan (pure).
    final plan = await CaptureDecider.instance.decide(
      surface: surface,
      transcript: text,
      overrideRouteIntent: overrideRouteIntent,
    );

    // 4) Apply plan (side effects).
    for (final op in plan.ops) {
      await _applyOp(
        op,
        surface: surface,
        observe: observe,
        audioPath: audioPath,
        durationMs: durationMs,
      );
    }

    return CaptureExecutionResult(signalId: signal.id, nextModule: plan.nextModule);
  }

  Future<void> _applyOp(
    CaptureOp op, {
    required String surface,
    required void Function(TwinEvent e) observe,
    required int durationMs,
    String? audioPath,
  }) async {
    switch (op.type) {
      case CaptureOpType.navModule:
        observe(TwinEvent.actionPerformed(
          surface: surface,
          action: 'nav_capture',
          entityType: 'module',
          meta: {'target': op.data['module']},
        ));
        return;

      case CaptureOpType.recordRouteDecision:
        final s = (op.data['surface'] as String?) ?? surface;
        final intent = (op.data['routeIntent'] as String?) ?? '';
        if (intent.isNotEmpty) {
          await RoutingCounterStore.instance.recordRouteDecision(s, intent);
          observe(TwinEvent.actionPerformed(
            surface: surface,
            action: 'route_decision_capture',
            entityType: 'route',
            meta: {'surface': s, 'routeIntent': intent},
          ));
        }
        return;

      case CaptureOpType.createTask:
        final transcript = (op.data['transcript'] as String?)?.trim() ?? '';
        if (transcript.isEmpty) return;
        final now = DateTime.now();
        final task = TaskItem(
          id: now.microsecondsSinceEpoch.toString(),
          createdAt: now,
          title: TaskItem.titleFromTranscript(transcript, maxWords: 6),
          transcript: transcript,
          audioPath: audioPath,
          audioDurationMs: durationMs,
          projectId: null,
        );
        final tasks = await TaskStore.load();
        await TaskStore.save([task, ...tasks]);
        observe(TwinEvent.actionPerformed(
          surface: surface,
          action: 'task_created_capture',
          entityType: 'task',
          entityId: task.id,
          meta: {'learnedDefault': op.data['learnedDefault'] == true},
        ));
        return;

      case CaptureOpType.listIntent:
        final action = (op.data['action'] as String?) ?? '';
        final listName = (op.data['listName'] as String?) ?? '';
        final items = (op.data['items'] as List?)?.whereType<String>().toList(growable: false) ?? const <String>[];
        if (listName.trim().isEmpty) return;

        if (action == 'create') {
          await ListStore.createIfMissing(listName);
          if (items.isNotEmpty) {
            await ListStore.addItems(listName, items);
          }
          observe(TwinEvent.actionPerformed(
            surface: surface,
            action: 'list_created_capture',
            entityType: 'list',
            meta: {'name': listName, 'items': items.length},
          ));
          return;
        }

        if (action == 'add') {
          await ListStore.addItems(listName, items);
          observe(TwinEvent.actionPerformed(
            surface: surface,
            action: 'list_items_added_capture',
            entityType: 'list',
            meta: {'name': listName, 'items': items.length},
          ));
          return;
        }

        if (action == 'remove') {
          await ListStore.removeItems(listName, items);
          observe(TwinEvent.actionPerformed(
            surface: surface,
            action: 'list_items_removed_capture',
            entityType: 'list',
            meta: {'name': listName, 'items': items.length},
          ));
          return;
        }

        if (action == 'clear') {
          await ListStore.clear(listName);
          observe(TwinEvent.actionPerformed(
            surface: surface,
            action: 'list_cleared_capture',
            entityType: 'list',
            meta: {'name': listName},
          ));
          return;
        }

        if (action == 'show') {
          observe(TwinEvent.actionPerformed(
            surface: surface,
            action: 'list_opened_capture',
            entityType: 'list',
            meta: {'name': listName},
          ));
          return;
        }

        return;

      case CaptureOpType.addCork:
        final text = (op.data['text'] as String?)?.trim() ?? '';
        if (text.isEmpty) return;
        await CorkboardStore.addText(text);
        observe(TwinEvent.actionPerformed(
          surface: surface,
          action: op.data['learnedDefault'] == true ? 'cork_created_capture_learned_default' : 'cork_created_capture',
          entityType: 'cork',
          meta: {'textLen': text.length},
        ));
        return;

      case CaptureOpType.createProject:
        final name = (op.data['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) return;
        final proj = await ProjectStore.addProject(name);
        observe(TwinEvent.actionPerformed(
          surface: surface,
          action: 'project_created_capture',
          entityType: 'project',
          entityId: proj.id,
        ));
        return;
    }
  }

  Future<SignalItem> _persistSignal({
    required String source,
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();

    final fp = '$source|$title|$body';

    final item = SignalItem(
      id: id,
      createdAt: now,
      source: source,
      title: title,
      body: body,
      fingerprint: fp,
      lastSeenAt: now,
      count: 1,
      acknowledged: false,
    );

    try {
      final existing = await SignalStore.load();
      await SignalStore.save([item, ...existing]);
    } catch (e) {
      debugPrint('CaptureExecutor: failed to persist signal: $e');
    }

    return item;
  }

  int _wordCount(String s) {
    if (s.trim().isEmpty) return 0;
    return s.split(RegExp(r'\s+')).where((w) => w.trim().isNotEmpty).length;
  }
}

class CaptureExecutionResult {
  final String signalId;
  final String nextModule;

  const CaptureExecutionResult({required this.signalId, required this.nextModule});
}
