// Tempus Victa rebuild - generated 2026-02-21
// Local-first, Android-first.


import 'package:flutter/material.dart';

import '../../data/models/signal.dart';
import '../../data/repositories/signal_repo.dart';
import '../../data/repositories/task_repo.dart';
import '../../data/repositories/recycle_repo.dart';
import '../../services/learning/learning_engine.dart';
import '../../services/logging/jsonl_logger.dart';
import '../../ui/tempus_scaffold.dart';
import '../../ui/widgets/glass_card.dart';
import '../../widgets/input_composer.dart';
import 'signal_detail_sheet.dart';

class SignalsScreen extends StatefulWidget {
  final void Function(int index) onNavigate;
  final int selectedIndex;

  const SignalsScreen({
    super.key,
    required this.onNavigate,
    required this.selectedIndex,
  });

  @override
  State<SignalsScreen> createState() => _SignalsScreenState();
}

class _SignalsScreenState extends State<SignalsScreen> {
  late Future<List<Signal>> _future;

  @override
  void initState() {
    super.initState();
    _future = SignalRepo.instance.list(status: 'inbox');
  }

  Future<void> _refresh() async {
    setState(() => _future = SignalRepo.instance.list(status: 'inbox'));
  }

  Future<void> _ingest({String? text, String? transcript}) async {
    final nowUtc = DateTime.now().toUtc();
    final s = await SignalRepo.instance.create(
      kind: transcript != null ? 'voice' : 'text',
      source: transcript != null ? 'signals_voice' : 'signals_text',
      text: text,
      transcript: transcript,
      capturedAtUtc: nowUtc,
    );
    await JsonlLogger.instance.append('signals.jsonl', {
      'event': 'signal_ingested',
      'id': s.id,
      'kind': s.kind,
      'source': s.source,
      'capturedAtUtc': nowUtc.toIso8601String(),
      'text': text,
      'transcript': transcript,
    });

    await _refresh();
  }

  Future<void> _toTask(Signal s) async {
    final nowUtc = DateTime.now().toUtc();
    final title = (s.kind == 'voice') ? (s.transcript ?? '') : (s.text ?? '');
    await TaskRepo.instance.create(
      title: title.isEmpty ? 'Follow up' : title,
      details: 'From Signal ${s.id}',
      source: 'signal_bay',
      signalId: s.id,
      capturedAtUtc: nowUtc,
    );
    await SignalRepo.instance.updateStatus(s.id, 'task');
    await LearningEngine.instance.bumpRoute(fromSource: s.source, toBucket: 'task');

    await JsonlLogger.instance.append('routing.jsonl', {
      'event': 'signal_routed',
      'signalId': s.id,
      'to': 'task',
      'atUtc': nowUtc.toIso8601String(),
    });

    await _refresh();
  }

  Future<void> _toRecycle(Signal s) async {
    await RecycleRepo.instance.moveToRecycle(signal: s, reason: 'swipe_left');
    await LearningEngine.instance.bumpRoute(fromSource: s.source, toBucket: 'task');
    await JsonlLogger.instance.log('signal_recycle', {'id': s.id, 'source': s.source});
    if (mounted) setState(() {});
  }

  String _preview(Signal s) {
    final v = s.kind == 'voice' ? (s.transcript ?? '') : (s.text ?? '');
    return v.length > 120 ? '${v.substring(0, 120)}…' : v;
  }

  @override
  Widget build(BuildContext context) {
    return TempusScaffold(
      title: 'Signal Bay',
      selectedIndex: widget.selectedIndex,
      onNavigate: widget.onNavigate,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _refresh,
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            GlassCard(
              child: InputComposer(
                hint: 'Quick capture into Signal Bay…',
                onSubmit: ({text, transcript}) => _ingest(text: text, transcript: transcript),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Signal>>(
                future: _future,
                builder: (context, snap) {
                  final items = snap.data ?? const <Signal>[];
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (items.isEmpty) {
                    return const Center(child: Text('Inbox is empty. Capture something on Bridge.'));
                  }

                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final s = items[i];
                      return Dismissible(
                        key: ValueKey(s.id),
                        background: _SwipeBg(label: 'TASK', icon: Icons.check_circle, alignment: Alignment.centerLeft),
                        secondaryBackground: _SwipeBg(label: 'RECYCLE', icon: Icons.delete, alignment: Alignment.centerRight),
                        confirmDismiss: (dir) async {
                          if (dir == DismissDirection.startToEnd) {
                            await _toTask(s);
                          } else {
                            await _toRecycle(s);
                          }
                          return false; // keep item until refresh removes it
                        },
                        child: InkWell(
                          onTap: () => showModalBottomSheet(
                            context: context,
                            showDragHandle: true,
                            builder: (_) => SignalDetailSheet(signal: s),
                          ),
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_preview(s), style: Theme.of(context).textTheme.bodyLarge),
                                const SizedBox(height: 6),
                                Text(
                                  'Captured UTC: ${s.capturedAtUtc.toIso8601String()} • Source: ${s.source}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  final String label;
  final IconData icon;
  final Alignment alignment;

  const _SwipeBg({required this.label, required this.icon, required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}