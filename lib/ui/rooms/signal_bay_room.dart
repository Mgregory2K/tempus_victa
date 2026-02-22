import 'package:flutter/material.dart';

import '../../core/app_state_scope.dart';
import '../../core/signal_item.dart';
import '../../core/signal_store.dart';
import '../../core/task_item.dart';
import '../../core/task_store.dart';
import '../../core/recycle_bin_store.dart';
import '../room_frame.dart';

class SignalBayRoom extends StatefulWidget {
  final String roomName;
  const SignalBayRoom({super.key, required this.roomName});

  @override
  State<SignalBayRoom> createState() => _SignalBayRoomState();
}

class _SignalBayRoomState extends State<SignalBayRoom> {
  List<SignalItem> _signals = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await SignalStore.load();
    if (!mounted) return;
    setState(() {
      _signals = items;
      _loading = false;
    });
  }

  Future<void> _persist() async => SignalStore.save(_signals);

  Future<void> _addDemoSignal() async {
    final now = DateTime.now();
    final s = SignalItem(
      id: now.microsecondsSinceEpoch.toString(),
      createdAt: now,
      source: 'demo',
      title: 'Demo signal @ ${_fmtTime(now)}',
      body: 'Swipe right → Task. Swipe left → Recycle.',
    );
    setState(() => _signals = [s, ..._signals]);
    await _persist();
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ap = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }

  Future<void> _sendToRecycle(SignalItem s) async {
    final bin = await RecycleBinStore.loadSignals();
    final updated = [s, ...bin];
    await RecycleBinStore.saveSignals(updated);
  }

  Future<void> _promoteToTask(SignalItem s) async {
    final tasks = await TaskStore.load();
    final now = DateTime.now();
    final t = TaskItem(
      id: now.microsecondsSinceEpoch.toString(),
      createdAt: now,
      title: s.title,
      transcript: s.body,
      audioPath: null,
      projectId: null,
    );
    await TaskStore.save([t, ...tasks]);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);

    return RoomFrame(
      title: widget.roomName,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Signals (triage queue)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _addDemoSignal,
                        icon: const Icon(Icons.add),
                        label: const Text('Add demo'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _signals.isEmpty
                      ? const Center(
                          child: Text('No signals yet. Add a demo signal to test swipes.'),
                        )
                      : ListView.builder(
                          itemCount: _signals.length,
                          itemBuilder: (context, i) {
                            final s = _signals[i];

                            return Dismissible(
                              key: ValueKey('signal_${s.id}'),
                              background: _SwipeBg(
                                icon: Icons.check_circle_rounded,
                                label: 'Make task',
                                alignLeft: true,
                              ),
                              secondaryBackground: _SwipeBg(
                                icon: Icons.delete_rounded,
                                label: 'Recycle',
                                alignLeft: false,
                              ),
                              confirmDismiss: (dir) async {
                                if (dir == DismissDirection.startToEnd) {
                                  // Promote to task, but keep list smooth: remove signal.
                                  await _promoteToTask(s);
                                  app.setSelectedModule('tasks');
                                  return true;
                                }
                                if (dir == DismissDirection.endToStart) {
                                  await _sendToRecycle(s);
                                  return true;
                                }
                                return false;
                              },
                              onDismissed: (_) async {
                                setState(() {
                                  _signals = List.of(_signals)..removeAt(i);
                                });
                                await _persist();
                              },
                              child: ListTile(
                                title: Text(s.title),
                                subtitle: s.body == null ? null : Text(s.body!, maxLines: 2, overflow: TextOverflow.ellipsis),
                                leading: const Icon(Icons.bolt_rounded),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool alignLeft;

  const _SwipeBg({
    required this.icon,
    required this.label,
    required this.alignLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: alignLeft ? Colors.green.withOpacity(0.25) : Colors.red.withOpacity(0.25),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisAlignment: alignLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (alignLeft) ...[
            Icon(icon),
            const SizedBox(width: 8),
            Text(label),
          ] else ...[
            Text(label),
            const SizedBox(width: 8),
            Icon(icon),
          ]
        ],
      ),
    );
  }
}
