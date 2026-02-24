import 'package:flutter/material.dart';

import '../../core/learning_store.dart';
import '../../core/twin_plus/twin_plus_kernel.dart';
import '../../core/twin_plus/twin_plus_scope.dart';
import '../room_frame.dart';
import '../theme/tempus_theme.dart';
import '../theme/tempus_ui.dart';

class AnalyzeRoom extends StatefulWidget {
  final String roomName;
  const AnalyzeRoom({super.key, required this.roomName});

  @override
  State<AnalyzeRoom> createState() => _AnalyzeRoomState();
}

class _AnalyzeRoomState extends State<AnalyzeRoom> {
  bool _loading = true;
  List<LearnedSource> _sources = const [];
  List<SuggestedRule> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final src = await LearningStore.listSources();
    final sug = LearningStore.suggest(src);
    if (!mounted) return;
    setState(() {
      _sources = src;
      _suggestions = sug;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = context.tv;
    final t = Theme.of(context).textTheme;

    return RoomFrame(
      title: 'Analyze',
      headerTrailing: IconButton(
        tooltip: 'Refresh',
        onPressed: _load,
        icon: const Icon(Icons.refresh),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                children: [
                  TempusCard(
                    elevated: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('What Tempus has learned', style: t.titleLarge),
                        const SizedBox(height: 6),
                        Text(
                          'This is early learning based on how you triage Signal Bay. '
                          'It will evolve into “do it for me” automations once you approve suggested rules.',
                          style: t.bodySmall?.copyWith(color: b.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  _hub(context),

                  const SizedBox(height: 16),
                  Text('Suggested automations', style: t.titleMedium),
                  const SizedBox(height: 10),

                  if (_suggestions.isEmpty)
                    TempusCard(
                      child: Text(
                        'No strong patterns yet. Use Signal Bay a bit more and Tempus will start proposing automations.',
                        style: t.bodyMedium,
                      ),
                    )
                  else
                    ..._suggestions.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TempusCard(
                            onTap: () => _openSuggestion(s),
                            child: Row(
                              children: [
                                Icon(_iconFor(s.type), color: b.accent),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_titleFor(s), style: t.titleMedium),
                                      const SizedBox(height: 2),
                                      Text(s.reason, style: t.bodySmall?.copyWith(color: b.muted)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        )),

                  const SizedBox(height: 12),
                  Text('Learning sources', style: t.titleMedium),
                  const SizedBox(height: 10),

                  if (_sources.isEmpty)
                    TempusCard(
                      child: Text(
                        'No learning data yet. Start triaging Signal Bay.',
                        style: t.bodyMedium,
                      ),
                    )
                  else
                    ..._sources.take(12).map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TempusCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.source, style: t.titleMedium),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    TempusPill(text: 'Total: ${s.total}'),
                                    TempusPill(text: 'Tasks: ${s.toTask}'),
                                    TempusPill(text: 'Cork: ${s.toCorkboard}'),
                                    TempusPill(text: 'Recycle: ${s.recycled}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )),
                  const SizedBox(height: 18),
                  _twinInspector(context),
                ],
              ),
            ),
    );
  }

  Widget _hub(BuildContext context) {
    // A stylized “brain hub” (not photo-real). We can do this with CustomPaint + cards.
    final b = context.tv;
    final t = Theme.of(context).textTheme;

    return SizedBox(
      height: 260,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _HubPainter(accent: b.accent))),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: b.surface2,
                border: Border.all(color: b.border),
                boxShadow: [BoxShadow(blurRadius: 18, color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? .35 : .10))],
              ),
              child: Icon(Icons.psychology_rounded, size: 42, color: b.accent),
            ),
          ),
          _hubCard(context, alignment: const Alignment(-0.9, -0.55), title: 'Accuracy', subtitle: 'Your corrections'),
          _hubCard(context, alignment: const Alignment(0.9, -0.55), title: 'Bias', subtitle: 'Your patterns'),
          _hubCard(context, alignment: const Alignment(-0.95, 0.55), title: 'Reliability', subtitle: 'Consistency'),
          _hubCard(context, alignment: const Alignment(0.95, 0.55), title: 'Efficiency', subtitle: 'Time saved'),
          _hubCard(context, alignment: const Alignment(0, 0.95), title: 'Explain', subtitle: 'Why it acted'),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Text(
              'Learning Map',
              style: t.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hubCard(BuildContext context, {required Alignment alignment, required String title, required String subtitle}) {
    final b = context.tv;
    final t = Theme.of(context).textTheme;
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: 140,
        child: TempusCard(
          padding: const EdgeInsets.all(12),
          onTap: () {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(subtitle, style: t.bodySmall?.copyWith(color: b.muted)),
            ],
          ),
        ),
      ),
    );
  }

  void _openSuggestion(SuggestedRule s) {
    final t = Theme.of(context).textTheme;
    final b = context.tv;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_titleFor(s), style: t.titleLarge),
              const SizedBox(height: 8),
              Text(s.reason, style: t.bodyMedium),
              const SizedBox(height: 12),
              Text(
                'Next step (not yet automated): add a toggle to approve this rule, then Tempus will apply it automatically.',
                style: t.bodySmall?.copyWith(color: b.muted),
              ),
              const SizedBox(height: 14),
            ],
          ),
        );
      },
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'mute':
        return Icons.volume_off_rounded;
      case 'autoTask':
        return Icons.playlist_add_check_rounded;
      case 'autoCork':
        return Icons.push_pin_rounded;
      default:
        return Icons.lightbulb_rounded;
    }
  }

  String _titleFor(SuggestedRule s) {
    switch (s.type) {
      case 'mute':
        return 'Mute ${s.source}';
      case 'autoTask':
        return 'Auto‑create task from ${s.source}';
      case 'autoCork':
        return 'Auto‑pin ${s.source} to Corkboard';
      default:
        return 'Suggestion for ${s.source}';
    }
  }

  Widget _twinInspector(BuildContext context) {
    final b = context.tv;
    final t = Theme.of(context).textTheme;
    final kernel = TwinPlusScope.of(context);

    // If Twin+ hasn't been initialized yet, still render a helpful card.
    if (!kernel.isReady) {
      return TempusCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Twin+ Inspector', style: t.titleMedium),
            const SizedBox(height: 6),
            Text('Twin+ not initialized yet. (This should only happen very early in app startup.)', style: t.bodyMedium?.copyWith(color: b.muted)),
          ],
        ),
      );
    }

    final snap = kernel.snapshot();
    final prefs = snap.prefs;
    final features = snap.features;

    String _s(dynamic v) => (v == null) ? '—' : v.toString();

    return TempusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_search_rounded, color: b.accent),
              const SizedBox(width: 8),
              Expanded(child: Text('Twin+ Inspector', style: t.titleMedium)),
              Text('${snap.recentEvents.length} ev', style: t.bodySmall?.copyWith(color: b.muted)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              TempusPill(text: 'AI Opt‑In: ${_s(prefs['aiOptIn'])}'),
              TempusPill(text: 'Just the facts: ${_s(prefs['justTheFactsActive'])}'),
              TempusPill(text: 'Length: ${_s(prefs['lengthDefault'])}'),
              TempusPill(text: 'Format: ${_s(prefs['formatDefault'])}'),
            ],
          ),
          const SizedBox(height: 10),
          Text('Style Features', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              TempusPill(text: 'Samples: ${_s(features['samples'])}'),
              TempusPill(text: 'Avg words: ${_s(features['avgWords'])}'),
              TempusPill(text: 'Caps rate: ${_s(features['capsRate'])}'),
              TempusPill(text: 'Profanity: ${_s(features['profanityRate'])}'),
            ],
          ),
          const SizedBox(height: 10),
          Text('Note: Twin+ is local, inspectable, and resettable. AI never becomes the memory.', style: t.bodySmall?.copyWith(color: b.muted)),
        ],
      ),
    );
  }
}

class _HubPainter extends CustomPainter {
  final Color accent;
  _HubPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);

    final points = [
      Offset(size.width * 0.15, size.height * 0.22),
      Offset(size.width * 0.85, size.height * 0.22),
      Offset(size.width * 0.12, size.height * 0.78),
      Offset(size.width * 0.88, size.height * 0.78),
      Offset(size.width * 0.50, size.height * 0.93),
    ];

    final line = Paint()
      ..color = accent.withOpacity(0.35)
      ..strokeWidth = 2;

    final dot = Paint()..color = accent.withOpacity(0.55);

    for (final p in points) {
      canvas.drawLine(center, p, line);
      canvas.drawCircle(p, 3.5, dot);
    }

    // subtle ring
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = accent.withOpacity(0.22);
    canvas.drawCircle(center, 52, ring);
    canvas.drawCircle(center, 62, ring..color = accent.withOpacity(0.12));
  }

  @override
  bool shouldRepaint(covariant _HubPainter oldDelegate) => oldDelegate.accent != accent;
}
