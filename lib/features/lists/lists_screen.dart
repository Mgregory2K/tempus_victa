// Tempus Victa - Lists
//
// Doctrine (from conception/textbook): lists are not static task lists;
// they are living systems. This screen is a practical "mansion" rebuild
// surface: grocery, recurring checklists, quick add.

import 'package:flutter/material.dart';

import '../../data/repositories/signal_repo.dart';
import '../../data/repositories/task_repo.dart';
import '../../services/learning/learning_engine.dart';
import '../../ui/tempus_scaffold.dart';
import '../../ui/widgets/glass_card.dart';
import '../../widgets/input_composer.dart';

class ListsScreen extends StatefulWidget {
  final void Function(int index) onNavigate;
  final int selectedIndex;

  const ListsScreen({
    super.key,
    required this.onNavigate,
    required this.selectedIndex,
  });

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  Future<void> _addGroceryItem(String text, {String source = 'lists'}) async {
    final now = DateTime.now().toUtc();
    final s = await SignalRepo.instance.create(
      kind: 'grocery_item',
      source: source,
      text: text,
      status: 'list',
      confidence: 0.7,
      weight: 0.3,
      capturedAtUtc: now,
    );
    // Keep a task too (so automation can schedule/order later).
    await TaskRepo.instance.create(
      title: 'Buy: $text',
      details: 'Captured from Lists (grocery)',
      source: source,
      signalId: s.id,
      capturedAtUtc: now,
    );
    await LearningEngine.instance.bumpRoute(fromSource: source, toBucket: 'list');
  }

  Future<void> _capture({String? text, String? transcript}) async {
    final raw = (text ?? transcript ?? '').trim();
    if (raw.isEmpty) return;

    // Lightweight deterministic intent.
    final lower = raw.toLowerCase();
    final looksLikeGrocery = lower.contains('grocery') ||
        lower.startsWith('buy ') ||
        lower.contains('kroger') ||
        lower.contains('walmart');

    if (looksLikeGrocery) {
      final cleaned = raw
          .replaceAll(RegExp(r'(?i)^(add\s+)?(to\s+)?(my\s+)?grocery\s+list\s*[:\-]?\s*'), '')
          .replaceAll(RegExp(r'(?i)^buy\s+'), '')
          .trim();
      await _addGroceryItem(cleaned.isEmpty ? raw : cleaned,
          source: transcript != null ? 'lists_voice' : 'lists_text');
    } else {
      // Default: treat as capture into inbox.
      final now = DateTime.now().toUtc();
      final s = await SignalRepo.instance.create(
        kind: transcript != null ? 'voice' : 'text',
        source: transcript != null ? 'lists_voice' : 'lists_text',
        text: text,
        transcript: transcript,
        status: 'inbox',
        confidence: 0.5,
        weight: 0.2,
        capturedAtUtc: now,
      );
      await TaskRepo.instance.create(
        title: raw,
        details: 'Captured from Lists',
        source: transcript != null ? 'lists_voice' : 'lists_text',
        signalId: s.id,
        capturedAtUtc: now,
      );
      await LearningEngine.instance.bumpRoute(
          fromSource: transcript != null ? 'lists_voice' : 'lists_text',
          toBucket: 'inbox');
    }

    if (!mounted) return;
    setState(() {});
  }

  Future<List<_ListItem>> _loadGrocery() async {
    final items = await SignalRepo.instance.list(status: 'list');
    // Only show grocery items on this surface.
    final g = items.where((s) => s.kind == 'grocery_item').toList();
    return g
        .map((s) => _ListItem(
            id: s.id,
            text: s.text ?? s.transcript ?? '(empty)',
            capturedAtUtc: s.capturedAtUtc))
        .toList();
  }

  Future<List<_TaskRow>> _loadDailyChecklist() async {
    final open = await TaskRepo.instance.list(status: 'open');
    // Show most recent open tasks as a "daily checklist".
    return open
        .take(12)
        .map((t) => _TaskRow(id: t.id, title: t.title))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return TempusScaffold(
      title: 'Lists',
      selectedIndex: widget.selectedIndex,
      onNavigate: widget.onNavigate,
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Quick Add',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                InputComposer(
                  hint: 'Add grocery item… (or capture anything)',
                  onSubmit: ({text, transcript}) =>
                      _capture(text: text, transcript: transcript),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tip: say "buy milk" or "add to grocery list: eggs" to route to Grocery.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<_ListItem>>(
            future: _loadGrocery(),
            builder: (context, snap) {
              final items = snap.data ?? const <_ListItem>[];
              return GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Grocery',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900)),
                        ),
                        Text('${items.length}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (items.isEmpty)
                      Text('No grocery items yet. Capture one.',
                          style: Theme.of(context).textTheme.bodyMedium)
                    else
                      for (final it in items)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.shopping_cart_outlined),
                          title: Text(it.text,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('Captured ${it.capturedAtUtc.toLocal()}'),
                          trailing: IconButton(
                            tooltip: 'Mark acquired',
                            icon: const Icon(Icons.check_circle_outline),
                            onPressed: () async {
                              await SignalRepo.instance.updateStatus(
                                  it.id, 'archived',
                                  confidence: 0.9);
                              await LearningEngine.instance.bumpRoute(
                                  fromSource: 'lists', toBucket: 'completed');
                              if (mounted) setState(() {});
                            },
                          ),
                        ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<_TaskRow>>(
            future: _loadDailyChecklist(),
            builder: (context, snap) {
              final tasks = snap.data ?? const <_TaskRow>[];
              return GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Checklist',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    if (tasks.isEmpty)
                      const Text(
                          'No open tasks. You\'re either crushing it… or avoiding it. 😄')
                    else
                      for (final t in tasks)
                        CheckboxListTile(
                          value: false,
                          onChanged: (_) async {
                            await TaskRepo.instance.setStatus(t.id, 'done');
                            if (mounted) setState(() {});
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(t.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ListItem {
  final String id;
  final String text;
  final DateTime capturedAtUtc;

  const _ListItem(
      {required this.id, required this.text, required this.capturedAtUtc});
}

class _TaskRow {
  final String id;
  final String title;

  const _TaskRow({required this.id, required this.title});
}
