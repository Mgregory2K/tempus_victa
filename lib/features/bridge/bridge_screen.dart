// Tempus Victa - Bridge (Today)
//
// From the conception + textbook:
// - Bridge is a psychological anchor, not a diagnostics dump.
// - Minimal, calm, but with quick access to modules.
// - Global mic capture is available via FAB (TempusScaffold).

import 'package:flutter/material.dart';

import '../../data/repositories/signal_repo.dart';
import '../../data/repositories/task_repo.dart';
import '../../services/ai/ai_key.dart';
import '../../ui/tempus_scaffold.dart';
import '../../ui/widgets/glass_card.dart';

class BridgeScreen extends StatefulWidget {
  final void Function(int index) onNavigate;
  final int selectedIndex;

  const BridgeScreen({
    super.key,
    required this.onNavigate,
    required this.selectedIndex,
  });

  @override
  State<BridgeScreen> createState() => _BridgeScreenState();
}

class _BridgeScreenState extends State<BridgeScreen> {
  Future<_TodayStats> _load() async {
    final open = await TaskRepo.instance.list(status: 'open');
    final done = await TaskRepo.instance.list(status: 'done');
    final inboxSignals = await SignalRepo.instance.list(status: 'inbox');
    return _TodayStats(
      openTasks: open.length,
      doneTasks: done.length,
      inboxSignals: inboxSignals.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TempusScaffold(
      title: 'Tempus Victa',
      selectedIndex: widget.selectedIndex,
      onNavigate: widget.onNavigate,
      actions: [
        IconButton(
          tooltip: 'AI Key',
          icon: const Icon(Icons.key),
          onPressed: () async {
            final controller = TextEditingController(text: (await AiKey.get()) ?? '');
            if (!context.mounted) return;
            final saved = await showDialog<bool>(
              context: context,
              builder: (ctx) {
                return AlertDialog(
                  title: const Text('OpenAI API Key'),
                  content: TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: 'sk-...'),
                    obscureText: true,
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () async {
                        final v = controller.text.trim();
                        if (v.isEmpty) {
                          await AiKey.clear();
                        } else {
                          await AiKey.set(v);
                        }
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                );
              },
            );
            if (saved == true && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI key saved')));
            }
          },
        ),
      ],
      body: FutureBuilder<_TodayStats>(
        future: _load(),
        builder: (context, snap) {
          final stats = snap.data ?? const _TodayStats(openTasks: 0, doneTasks: 0, inboxSignals: 0);

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Brief', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _Metric(label: 'Open Tasks', value: stats.openTasks.toString())),
                        Expanded(child: _Metric(label: 'Completed', value: stats.doneTasks.toString())),
                        Expanded(child: _Metric(label: 'Inbox Signals', value: stats.inboxSignals.toString())),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tap mic (bottom-right) to capture anything. Tempus will store it as a Signal + Task immediately.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Quick access cards (concept vibe)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick Launch', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _QuickChip(label: 'Signal Bay', icon: Icons.inbox, onTap: () => widget.onNavigate(4)),
                        _QuickChip(label: 'Actions', icon: Icons.check_circle, onTap: () => widget.onNavigate(5)),
                        _QuickChip(label: 'Corkboard', icon: Icons.push_pin, onTap: () => widget.onNavigate(6)),
                        _QuickChip(label: 'Recycle', icon: Icons.delete_outline, onTap: () => widget.onNavigate(7)),
                        _QuickChip(label: 'Ready Room', icon: Icons.forum, onTap: () => widget.onNavigate(8)),
                        _QuickChip(label: 'Settings', icon: Icons.settings, onTap: () => widget.onNavigate(9)),
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
                    Text('What Tempus is doing (local-first)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    const Text('• Ingestion is live: voice, share-sheet, and notification listener sources.'),
                    const Text('• Everything is timestamped (captured/created/modified UTC).'),
                    const Text('• Autopilot runs locally (gated by confidence thresholds).'),
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

class _QuickChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.45),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
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

class _TodayStats {
  final int openTasks;
  final int doneTasks;
  final int inboxSignals;

  const _TodayStats({
    required this.openTasks,
    required this.doneTasks,
    required this.inboxSignals,
  });
}
