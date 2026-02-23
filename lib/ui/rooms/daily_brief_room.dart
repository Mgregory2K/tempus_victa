import 'package:flutter/material.dart';
import '../../core/metrics_store.dart';

class DailyBriefRoom extends StatefulWidget {
  final String? roomName;
  const DailyBriefRoom({super.key, this.roomName});

  @override
  State<DailyBriefRoom> createState() => _DailyBriefRoomState();
}

class _DailyBriefRoomState extends State<DailyBriefRoom> {
  late Future<MetricsSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = MetricsStore.todaySnapshot(const [
      TvMetrics.signalsIngested,
      TvMetrics.tasksCreatedManual,
      TvMetrics.tasksCreatedVoice,
      TvMetrics.webSearches,
      TvMetrics.aiCalls,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MetricsSnapshot>(
      future: _future,
      builder: (context, snap) {
        final theme = Theme.of(context);
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final m = snap.data!;
        final tasks =
            (m.metrics[TvMetrics.tasksCreatedManual] ?? 0) + (m.metrics[TvMetrics.tasksCreatedVoice] ?? 0);

        final today = DateTime.now();
        final todayLabel = '${today.year.toString().padLeft(4, '0')}-'
            '${today.month.toString().padLeft(2, '0')}-'
            '${today.day.toString().padLeft(2, '0')}';

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.roomName ?? 'Daily Brief', style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text('Today ($todayLabel)',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
              const SizedBox(height: 16),
              _tile(context, 'Signals ingested', m.metrics[TvMetrics.signalsIngested] ?? 0),
              const SizedBox(height: 10),
              _tile(context, 'Tasks created', tasks),
              const SizedBox(height: 10),
              _tile(context, 'Web searches', m.metrics[TvMetrics.webSearches] ?? 0),
              const SizedBox(height: 10),
              _tile(context, 'AI replies', m.metrics[TvMetrics.aiCalls] ?? 0),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _showBriefSheet(context, m),
                  child: const Text('Show brief'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, String label, int value) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.titleMedium)),
            Text('$value', style: theme.textTheme.titleLarge),
          ],
        ),
      ),
    );
  }

  void _showBriefSheet(BuildContext context, MetricsSnapshot model) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => _BriefSheet(model: model),
    );
  }
}

class _BriefSheet extends StatelessWidget {
  final MetricsSnapshot model;
  const _BriefSheet({required this.model});

  @override
  Widget build(BuildContext context) {
    final signals = model.metrics[TvMetrics.signalsIngested] ?? 0;
    final tasks = (model.metrics[TvMetrics.tasksCreatedManual] ?? 0) + (model.metrics[TvMetrics.tasksCreatedVoice] ?? 0);
    final web = model.metrics[TvMetrics.webSearches] ?? 0;
    final ai = model.metrics[TvMetrics.aiCalls] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Summary', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text('Signals today: $signals'),
          Text('Tasks created today: $tasks'),
          Text('Web searches today: $web'),
          Text('AI replies today: $ai'),
          const SizedBox(height: 8),
          Text(
            'Tip: Signals that you acknowledge but don’t act on are still valuable. '
            'Tempus, Victa keeps them in the log so you can spot patterns later.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
