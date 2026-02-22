// Tempus Victa - scaffold
//
// - Persistent bottom navigation (concept-aligned)
// - Global microphone access (capture sheet)
// - Background styling

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/repositories/signal_repo.dart';
import '../data/repositories/task_repo.dart';
import '../services/learning/learning_engine.dart';
import '../services/logging/jsonl_logger.dart';
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
    // Ensures bottom nav never hides behind Android gesture/nav bars.
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
      floatingActionButton: enableGlobalCapture
          ? FloatingActionButton(
              tooltip: 'Capture (text or voice)',
              onPressed: () => _openCaptureSheet(context),
              child: const Icon(Icons.mic),
            )
          : null,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: math.max(8, MediaQuery.of(context).viewPadding.bottom)),
          child: TempusCarouselNav(
            selectedIndex: selectedIndex,
            onTap: onNavigate,
          ),
        ),
      ),
    );
  }

  Future<void> _openCaptureSheet(BuildContext context) async {
    // Global capture: everything becomes a Signal + an Inbox Task, immediately.
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(left: 12, right: 12, bottom: bottom + 12),
          child: _GlobalCapture(
            onCaptured: (m) {
              if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Captured ✅')));
            },
          ),
        );
      },
    );
  }
}

class _GlobalCapture extends StatefulWidget {
  final void Function(Map<String, Object?> result) onCaptured;
  const _GlobalCapture({required this.onCaptured});

  @override
  State<_GlobalCapture> createState() => _GlobalCaptureState();
}

class _GlobalCaptureState extends State<_GlobalCapture> {
  bool _busy = false;

  Future<void> _ingest({String? text, String? transcript}) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final nowUtc = DateTime.now().toUtc();
      final source = (transcript != null && transcript.trim().isNotEmpty) ? 'global_voice' : 'global_text';

      final s = await SignalRepo.instance.create(
        kind: (transcript != null && transcript.trim().isNotEmpty) ? 'voice' : 'text',
        source: source,
        text: text,
        transcript: transcript,
        capturedAtUtc: nowUtc,
        status: 'inbox',
        confidence: 0.5,
        weight: 0.2,
      );

      // Deterministic route.
      final raw = (transcript ?? text ?? '').trim();
      final route = CommandRouter.route(raw);
      final payload = route.payload.isEmpty ? raw : route.payload;

      await TaskRepo.instance.create(
        title: route.kind == 'unknown' ? 'Follow up: $payload' : payload,
        details: route.kind == 'unknown' ? null : 'Intent: ${route.kind}',
        source: source,
        signalId: s.id,
        capturedAtUtc: nowUtc,
      );

      await LearningEngine.instance.bumpRoute(fromSource: source, toBucket: 'inbox');
      await JsonlLogger.instance.log('capture', {'signalId': s.id, 'source': source});

      widget.onCaptured({'signalId': s.id, 'source': source});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Capture', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(
          'Text or voice. Everything becomes an Inbox Signal + an Inbox Task immediately.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        InputComposer(
          hint: 'Say/type anything… ("create a task …", "create a project …", etc.)',
          onSubmit: ({text, transcript}) => _ingest(text: text, transcript: transcript),
        ),
      ],
    );
  }
}
