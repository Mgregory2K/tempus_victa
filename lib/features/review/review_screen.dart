// Tempus Victa - Review
//
// End-of-day / system review surface.
// Shows what the system captured, what got done, and what it learned.
// Local-first only (no webapp).

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/signal_repo.dart';
import '../../data/repositories/task_repo.dart';
import '../../ui/tempus_scaffold.dart';
import '../../ui/widgets/glass_card.dart';

class ReviewScreen extends StatefulWidget {
  final void Function(int index) onNavigate;
  final int selectedIndex;

  const ReviewScreen({
    super.key,
    required this.onNavigate,
    required this.selectedIndex,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  Future<_ReviewData> _load() async {
    final open = await TaskRepo.instance.list(status: 'open');
    final done = await TaskRepo.instance.list(status: 'done');
    final inbox = await SignalRepo.instance.list(status: 'inbox');
    final list = await SignalRepo.instance.list(status: 'list');

    final d = await AppDb.instance.db;

    final evCount = Sqflite.firstIntValue(await d.rawQuery('SELECT COUNT(*) FROM learning_events')) ?? 0;
    final lastEvents = await d.rawQuery(
      'SELECT event_type, entity_type, source, score_delta, occurred_at_utc FROM learning_events ORDER BY occurred_at_utc DESC LIMIT 20',
    );

    final weights = await d.rawQuery(
      'SELECT k, v, updated_at_utc FROM learning_weights ORDER BY updated_at_utc DESC LIMIT 20',
    );

    return _ReviewData(
      openTasks: open.length,
      doneTasks: done.length,
      inboxSignals: inbox.length,
      listSignals: list.length,
      learningEventCount: evCount,
      lastEvents: lastEvents,
      lastWeights: weights,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TempusScaffold(
      title: 'Review',
      selectedIndex: widget.selectedIndex,
      onNavigate: widget.onNavigate,
      body: FutureBuilder<_ReviewData>(
        future: _load(),
        builder: (context, snap) {
          final data = snap.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today, at a glance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _Metric(label: 'Open', value: data.openTasks.toString())),
                        Expanded(child: _Metric(label: 'Done', value: data.doneTasks.toString())),
                        Expanded(child: _Metric(label: 'Inbox', value: data.inboxSignals.toString())),
                        Expanded(child: _Metric(label: 'Lists', value: data.listSignals.toString())),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Learning activity', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text('Events logged: ${data.learningEventCount}'),
                    const SizedBox(height: 10),
                    if (data.lastEvents.isEmpty)
                      const Text('No learning events yet. Capture + complete tasks to train the system.')
                    else
                      for (final r in data.lastEvents)
                        _EventRow(
                          eventType: (r['event_type'] ?? '').toString(),
                          entityType: (r['entity_type'] ?? '').toString(),
                          source: (r['source'] ?? '').toString(),
                          scoreDelta: (r['score_delta'] is num) ? (r['score_delta'] as num).toDouble() : double.tryParse((r['score_delta'] ?? '0').toString()) ?? 0,
                          occurredAtUtc: DateTime.fromMillisecondsSinceEpoch((r['occurred_at_utc'] as int?) ?? 0, isUtc: true),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recent learned weights', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    if (data.lastWeights.isEmpty)
                      const Text('No weights yet.')
                    else
                      for (final w in data.lastWeights)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text((w['k'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('v=${w['v']}'),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Next moves', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    const Text('• Capture everything via mic or share-sheet.'),
                    const Text('• Route signals in Signal Bay.'),
                    const Text('• Complete tasks in Actions to train weights.'),
                    const Text('• Use Lists for groceries/checklists.'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  final String eventType;
  final String entityType;
  final String source;
  final double scoreDelta;
  final DateTime occurredAtUtc;

  const _EventRow({
    required this.eventType,
    required this.entityType,
    required this.source,
    required this.scoreDelta,
    required this.occurredAtUtc,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.bolt),
      title: Text('$eventType • $entityType', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('$source • Δ ${scoreDelta.toStringAsFixed(2)} • ${occurredAtUtc.toLocal()}'),
    );
  }
}

class _ReviewData {
  final int openTasks;
  final int doneTasks;
  final int inboxSignals;
  final int listSignals;
  final int learningEventCount;
  final List<Map<String, Object?>> lastEvents;
  final List<Map<String, Object?>> lastWeights;

  const _ReviewData({
    required this.openTasks,
    required this.doneTasks,
    required this.inboxSignals,
    required this.listSignals,
    required this.learningEventCount,
    required this.lastEvents,
    required this.lastWeights,
  });
}
