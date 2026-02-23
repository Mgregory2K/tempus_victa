import 'package:flutter/material.dart';

import '../../core/metrics_store.dart';
import '../../core/task_item.dart';
import '../../core/task_store.dart';
import '../room_frame.dart';

/// Phase-1 Daily Brief (local-first).
///
/// This intentionally avoids AI. It is a deterministic summary of what the app
/// already knows: tasks + basic usage metrics.
class DailyBriefRoom extends StatefulWidget {
  final String roomName;
  const DailyBriefRoom({super.key, required this.roomName});

  @override
  State<DailyBriefRoom> createState() => _DailyBriefRoomState();
}

class _DailyBriefRoomState extends State<DailyBriefRoom> {
  late Future<_BriefModel> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_BriefModel> _load() async {
    final tasks = await TaskStore.load();
    final open = tasks; // no done-state yet
    final metrics = await MetricsStore.todaySnapshot(const [
      TvMetrics.signalsIngested,
      TvMetrics.tasksCreatedManual,
      TvMetrics.tasksCreatedVoice,
      TvMetrics.webSearches,
      TvMetrics.aiCalls,
    ]);
    return _BriefModel(openTasks: open, metrics: metrics);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  Future<void> _showBrief(_BriefModel m) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _BriefSheet(model: m),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RoomFrame(
      title: widget.roomName,
      child: FutureBuilder<_BriefModel>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final m = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _card(
                context,
                title: 'Today',
                child: Column(
                  children: [
                    _row(context, 'Signals', m.metrics[TvMetrics.signalsIngested] ?? 0),
                    _row(context, 'Tasks (manual)', m.metrics[TvMetrics.tasksCreatedManual] ?? 0),
                    _row(context, 'Tasks (voice)', m.metrics[TvMetrics.tasksCreatedVoice] ?? 0),
                    _row(context, 'Web searches', m.metrics[TvMetrics.webSearches] ?? 0),
                    _row(context, 'AI replies', m.metrics[TvMetrics.aiCalls] ?? 0),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                context,
                title: 'Open tasks',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${m.openTasks.length} total'),
                    const SizedBox(height: 10),
                    ...m.openTasks.take(5).map((t) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('• ${t.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
                        )),
                    if (m.openTasks.isEmpty)
                      Text(
                        'Nothing yet.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showBrief(m),
                      icon: const Icon(Icons.summarize_rounded),
                      label: const Text('Show brief'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tap “Show brief” for a quick summary you can trust.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, {required String title, required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.18)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, int value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value.toString(), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _BriefModel {
  final List<TaskItem> openTasks;
  final Map<String, int> metrics;
  const _BriefModel({required this.openTasks, required this.metrics});
}

class _BriefSheet extends StatelessWidget {
  final _BriefModel model;
  const _BriefSheet({required this.model});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      child: ListView(
        children: [
          Text('Daily Brief', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            'Short. Correct. Local-first.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 12),
          Text('Open tasks: ${model.openTasks.length}'),
          const SizedBox(height: 6),
          Text('Signals today: ${model.metrics[TvMetrics.signalsIngested] ?? 0}'),
          const SizedBox(height: 6),
          Text('Tasks created today: ${(model.metrics[TvMetrics.tasksCreatedManual] ?? 0) + (model.metrics[TvMetrics.tasksCreatedVoice] ?? 0)}'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check_rounded),
            label: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
