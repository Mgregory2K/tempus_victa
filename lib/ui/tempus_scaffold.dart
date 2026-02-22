// Tempus Victa - scaffold
//
// Doctrine:
// - Bottom "module ring" nav lives here (NOT RootShell).
// - Capture input lives ABOVE the module ring (per UX directive).
// - No machine-talk in UI; all logging is local (JSONL/DB).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/repositories/signal_repo.dart';
import '../data/repositories/task_repo.dart';
import '../services/learning/learning_engine.dart';
import '../services/routing/command_router.dart';
import '../ui/widgets/tempus_background.dart';
import '../ui/widgets/tempus_carousel_nav.dart';
import '../widgets/input_composer.dart';

class TempusScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final int selectedIndex;
  final ValueChanged<int> onNavigate;
  final List<Widget>? actions;
  final bool enableGlobalCapture;

  const TempusScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.selectedIndex,
    required this.onNavigate,
    this.actions,
    this.enableGlobalCapture = true,
  });

  @override
  Widget build(BuildContext context) {
    // MUST be double for EdgeInsets.only
    final double bottomPad = math.max(
      8.0,
      MediaQuery.of(context).viewPadding.bottom.toDouble(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      body: TempusBackground(
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: body,
          ),
        ),
      ),

      // Capture input ABOVE the module nav (persistent).
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (enableGlobalCapture)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: _BottomCaptureBar(
                    onCaptured: ({String? text, String? transcript}) async {
                      await _capture(
                        text: text,
                        transcript: transcript,
                        source: transcript != null ? 'global_voice' : 'global_text',
                      );
                    },
                  ),
                ),
              TempusCarouselNav(
                selectedIndex: selectedIndex,
                onTap: onNavigate,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _capture({
    String? text,
    String? transcript,
    required String source,
  }) async {
    final content = (transcript ?? text ?? '').trim();
    if (content.isEmpty) return;

    // 1) Persist a Signal immediately.
    final signal = await SignalRepo.instance.create(
      kind: 'capture',
      source: source,
      text: text,
      transcript: transcript,
      status: 'inbox',
      confidence: 0,
      weight: 0,
    );

    // 2) Always create an Inbox Task so nothing is lost.
    final route = CommandRouter.route(content);
    final payload = route.payload.trim().isEmpty ? content : route.payload.trim();

    // Deterministic routing (first-pass).
    if (route.kind == 'task') {
      await TaskRepo.instance.create(
        title: payload.isEmpty ? 'New task' : payload,
        source: source,
        signalId: signal.id,
      );
      await LearningEngine.instance.bumpRoute(fromSource: source, toBucket: 'task', delta: 1);
    } else if (route.kind == 'project') {
      // Until Projects are first-class again, represent projects as tasks.
      await TaskRepo.instance.create(
        title: payload.isEmpty ? 'New project' : 'Project: $payload',
        source: source,
        signalId: signal.id,
      );
      await LearningEngine.instance.bumpRoute(fromSource: source, toBucket: 'project', delta: 1);
    } else if (route.kind == 'reminder') {
      await TaskRepo.instance.create(
        title: payload.isEmpty ? 'New reminder' : 'Reminder: $payload',
        source: source,
        signalId: signal.id,
      );
      await LearningEngine.instance.bumpRoute(fromSource: source, toBucket: 'reminder', delta: 1);
    } else {
      await TaskRepo.instance.create(
        title: content.length > 80 ? 'Follow up: ${content.substring(0, 80)}…' : 'Follow up: $content',
        source: source,
        signalId: signal.id,
      );
      await LearningEngine.instance.bumpRoute(fromSource: source, toBucket: 'inbox', delta: 1);
    }
  }
}

class _BottomCaptureBar extends StatelessWidget {
  final Future<void> Function({String? text, String? transcript}) onCaptured;

  const _BottomCaptureBar({
    required this.onCaptured,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: InputComposer(
          enabled: true,
          hint: 'Say it or type it… (saved instantly)',
          onSubmit: onCaptured,
        ),
      ),
    );
  }
}