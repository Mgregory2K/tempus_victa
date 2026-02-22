// Tempus Vista rebuild - generated 2026-02-21
// Local-first, Android-first.


import 'package:flutter/material.dart';

import '../../data/models/task.dart';
import '../../data/repositories/task_repo.dart';
import '../../services/logging/jsonl_logger.dart';
import '../../services/learning/learning_engine.dart';
import '../../ui/tempus_scaffold.dart';
import '../../ui/widgets/glass_card.dart';
import '../../widgets/input_composer.dart';

class ActionsScreen extends StatefulWidget {
  final void Function(int index)? onNavigate;
  final int? selectedIndex;

  const ActionsScreen({
    super.key,
    this.onNavigate,
    this.selectedIndex,
  });

  @override
  State<ActionsScreen> createState() => _ActionsScreenState();
}

class _ActionsScreenState extends State<ActionsScreen> {
  late Future<List<Task>> _future;

  @override
  void initState() {
    super.initState();
    _future = TaskRepo.instance.list(status: 'open');
  }

  Future<void> _refresh() async {
    setState(() => _future = TaskRepo.instance.list(status: 'open'));
  }

  Future<void> _create({String? text, String? transcript}) async {
    final nowUtc = DateTime.now().toUtc();
    final title = (text ?? transcript ?? '').trim();
    if (title.isEmpty) return;

    final t = await TaskRepo.instance.create(
      title: title,
      details: transcript != null ? 'From voice: "$transcript"' : null,
      source: transcript != null ? 'actions_voice' : 'actions_text',
      capturedAtUtc: nowUtc,
    );

    await JsonlLogger.instance.append('tasks.jsonl', {
      'event': 'task_created',
      'id': t.id,
      'title': title,
      'atUtc': nowUtc.toIso8601String(),
      'source': t.source,
    });

    await _refresh();
  }

  Future<void> _done(Task t) async {
    final nowUtc = DateTime.now().toUtc();
    await TaskRepo.instance.setStatus(t.id, 'done');
    await LearningEngine.instance.bumpComplete(fromSource: t.source, taskId: t.id);
    await JsonlLogger.instance.append('tasks.jsonl', {
      'event': 'task_done',
      'id': t.id,
      'atUtc': nowUtc.toIso8601String(),
    });
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return TempusScaffold(
      title: 'Actions',
      selectedIndex: widget.selectedIndex ?? 2,
      onNavigate: widget.onNavigate ?? (_) {},
      actions: [
        IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
      ],
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            GlassCard(
              child: InputComposer(
                hint: 'Create a task…',
                onSubmit: ({text, transcript}) => _create(text: text, transcript: transcript),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Task>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snap.data ?? const <Task>[];
                  if (items.isEmpty) return const Center(child: Text('No open tasks.'));

                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final t = items[i];
                      return GlassCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.title, style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Captured UTC: ${t.capturedAtUtc.toIso8601String()} • Source: ${t.source}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  if ((t.details ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(t.details!),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Done',
                              onPressed: () => _done(t),
                              icon: const Icon(Icons.check_circle),
                            ),
                          ],
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
