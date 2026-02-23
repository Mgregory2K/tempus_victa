import 'package:flutter/material.dart';

import '../../core/learning_store.dart';
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
  Future<_LearnView> _load() async {
    final bySource = await LearningStore.summarizeBySource(days: 30);
    final topFp = await LearningStore.topFingerprints(limit: 25, days: 30);

    // Heuristic learning (deterministic):
    // - muteCandidate: recycle dominates and total >= 5
    // - autoPromoteCandidate: promote_task dominates and total >= 4
    // - autoPinCandidate: pin_cork dominates and total >= 4
    final muteCandidates = <_Candidate>[];
    final promoteCandidates = <_Candidate>[];
    final pinCandidates = <_Candidate>[];

    for (final row in topFp) {
      final src = (row['source'] as String?) ?? 'unknown';
      final fp = (row['fingerprint'] as String?) ?? '';
      final promote = (row['promote_task'] as int?) ?? 0;
      final pin = (row['pin_cork'] as int?) ?? 0;
      final recycle = (row['recycle'] as int?) ?? 0;
      final ack = (row['ack'] as int?) ?? 0;
      final total = (row['total'] as int?) ?? 0;

      if (total < 4) continue;

      // score is dominance ratio
      if (recycle >= 3 && recycle >= promote + pin && total >= 5) {
        muteCandidates.add(_Candidate(src, fp, 'You usually recycle these.', recycle, total));
      } else if (promote >= 3 && promote >= recycle + pin) {
        promoteCandidates.add(_Candidate(src, fp, 'You usually promote these to Tasks.', promote, total));
      } else if (pin >= 3 && pin >= recycle + promote) {
        pinCandidates.add(_Candidate(src, fp, 'You usually pin these to Corkboard.', pin, total));
      }
    }

    // Also show high-signal sources (by volume)
    final sources = bySource.entries.toList()
      ..sort((a, b) {
        final at = a.value.values.fold<int>(0, (p, c) => p + c);
        final bt = b.value.values.fold<int>(0, (p, c) => p + c);
        return bt.compareTo(at);
      });

    return _LearnView(
      sources: sources.take(8).map((e) => _SourceSummary(e.key, e.value)).toList(growable: false),
      muteCandidates: muteCandidates.take(10).toList(growable: false),
      promoteCandidates: promoteCandidates.take(10).toList(growable: false),
      pinCandidates: pinCandidates.take(10).toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = context.tv;

    return RoomFrame(
      title: widget.roomName,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder<_LearnView>(
          future: _load(),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final v = snap.data!;
            return ListView(
              children: [
                TempusCard(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.psychology_rounded, color: b.accent),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text('Analyze', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This is local learning from your behavior (no AI required). '
                          'As you triage signals, Tempus learns patterns and suggests automation.',
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            TempusPill(text: 'Local-first'),
                            TempusPill(text: 'Learns from actions'),
                            TempusPill(text: 'Suggests automation'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _sectionTitle('Automation suggestions'),
                const SizedBox(height: 8),
                _suggestionTile(
                  icon: Icons.visibility_off,
                  title: 'Mute candidates',
                  subtitle: v.muteCandidates.isEmpty
                      ? 'No patterns yet. Recycle/ack a few more signals.'
                      : 'Sources/signals you usually recycle.',
                  onTap: () => _openCandidates(ctx, 'Mute candidates', v.muteCandidates),
                ),
                const SizedBox(height: 10),
                _suggestionTile(
                  icon: Icons.task_alt,
                  title: 'Auto-promote candidates',
                  subtitle: v.promoteCandidates.isEmpty
                      ? 'No patterns yet. Promote a few signals into tasks.'
                      : 'Signals you usually turn into Tasks.',
                  onTap: () => _openCandidates(ctx, 'Auto-promote candidates', v.promoteCandidates),
                ),
                const SizedBox(height: 10),
                _suggestionTile(
                  icon: Icons.push_pin,
                  title: 'Auto-pin candidates',
                  subtitle: v.pinCandidates.isEmpty
                      ? 'No patterns yet. Pin a few signals to the Corkboard.'
                      : 'Signals you usually pin to Corkboard.',
                  onTap: () => _openCandidates(ctx, 'Auto-pin candidates', v.pinCandidates),
                ),

                const SizedBox(height: 14),
                _sectionTitle('Signal sources (last 30 days)'),
                const SizedBox(height: 8),
                if (v.sources.isEmpty)
                  TempusCard(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text('No learning data yet. Use Signal Bay to triage notifications.', style: b.body),
                    ),
                  )
                else
                  ...v.sources.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TempusCard(
                          onTap: () => _openSource(ctx, s),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(Icons.apps, color: b.accent),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.source, style: const TextStyle(fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 4),
                                      Text(_sourceSummaryText(s.actions), style: b.muted),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 2),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900)),
      );

  Widget _suggestionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final b = context.tv;
    return TempusCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: b.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: b.muted),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  void _openCandidates(BuildContext ctx, String title, List<_Candidate> cands) {
    showModalBottomSheet(
      context: ctx,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        final b = ctx.tv;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 8),
                Text(
                  cands.isEmpty
                      ? 'No candidates yet. Tempus needs a few repeats to learn patterns.'
                      : 'These are the highest-confidence repeated patterns (local).',
                  style: b.body,
                ),
                const SizedBox(height: 12),
                if (cands.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: cands.length,
                      separatorBuilder: (_, __) => const Divider(height: 14),
                      itemBuilder: (_, i) {
                        final c = cands[i];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.source, style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(c.reason, style: b.muted),
                            const SizedBox(height: 6),
                            Text('Pattern score: ${c.hits}/${c.total}', style: b.muted),
                          ],
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openSource(BuildContext ctx, _SourceSummary s) {
    showModalBottomSheet(
      context: ctx,
      showDragHandle: true,
      builder: (_) {
        final b = ctx.tv;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.source, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 10),
                Text(_sourceSummaryText(s.actions), style: b.body),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
              ],
            ),
          ),
        );
      },
    );
  }

  String _sourceSummaryText(Map<String, int> actions) {
    final parts = <String>[];
    void add(String k, String label) {
      final v = actions[k] ?? 0;
      if (v > 0) parts.add('$label: $v');
    }

    add('promote_task', 'Promoted');
    add('pin_cork', 'Pinned');
    add('recycle', 'Recycled');
    add('ack', 'Acknowledged');
    return parts.isEmpty ? 'No actions recorded yet.' : parts.join(' • ');
  }
}

class _LearnView {
  final List<_SourceSummary> sources;
  final List<_Candidate> muteCandidates;
  final List<_Candidate> promoteCandidates;
  final List<_Candidate> pinCandidates;

  _LearnView({
    required this.sources,
    required this.muteCandidates,
    required this.promoteCandidates,
    required this.pinCandidates,
  });
}

class _SourceSummary {
  final String source;
  final Map<String, int> actions;
  _SourceSummary(this.source, this.actions);
}

class _Candidate {
  final String source;
  final String fingerprint;
  final String reason;
  final int hits;
  final int total;
  _Candidate(this.source, this.fingerprint, this.reason, this.hits, this.total);
}
