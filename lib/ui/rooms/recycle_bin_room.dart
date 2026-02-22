import 'package:flutter/material.dart';

import '../../core/recycle_bin_store.dart';
import '../../core/signal_item.dart';
import '../../core/signal_store.dart';
import '../../core/task_item.dart';
import '../../core/task_store.dart';
import '../room_frame.dart';

class RecycleBinRoom extends StatefulWidget {
  final String roomName;
  const RecycleBinRoom({super.key, required this.roomName});

  @override
  State<RecycleBinRoom> createState() => _RecycleBinRoomState();
}

class _RecycleBinRoomState extends State<RecycleBinRoom> {
  List<SignalItem> _signals = const [];
  List<TaskItem> _tasks = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await RecycleBinStore.loadSignals();
    final t = await RecycleBinStore.loadTasks();
    if (!mounted) return;
    setState(() {
      _signals = s;
      _tasks = t;
      _loading = false;
    });
  }

  Future<void> _restoreSignal(SignalItem item) async {
    final currentSignals = await SignalStore.load();
    await SignalStore.save([item, ...currentSignals]);

    final updated = List.of(_signals)..removeWhere((x) => x.id == item.id);
    setState(() => _signals = updated);
    await RecycleBinStore.saveSignals(updated);
  }

  Future<void> _restoreTask(TaskItem item) async {
    final currentTasks = await TaskStore.load();
    await TaskStore.save([item, ...currentTasks]);

    final updated = List.of(_tasks)..removeWhere((x) => x.id == item.id);
    setState(() => _tasks = updated);
    await RecycleBinStore.saveTasks(updated);
  }

  Future<void> _deleteSignalForever(SignalItem item) async {
    final updated = List.of(_signals)..removeWhere((x) => x.id == item.id);
    setState(() => _signals = updated);
    await RecycleBinStore.saveSignals(updated);
  }

  Future<void> _deleteTaskForever(TaskItem item) async {
    final updated = List.of(_tasks)..removeWhere((x) => x.id == item.id);
    setState(() => _tasks = updated);
    await RecycleBinStore.saveTasks(updated);
  }

  @override
  Widget build(BuildContext context) {
    return RoomFrame(
      title: widget.roomName,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text('Deleted Tasks', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                if (_tasks.isEmpty)
                  const ListTile(title: Text('No deleted tasks.'))
                else
                  ..._tasks.map((t) => ListTile(
                        leading: const Icon(Icons.task_alt_rounded),
                        title: Text(t.title),
                        subtitle: t.audioPath != null ? const Text('Voice task (audio attached)') : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Restore',
                              icon: const Icon(Icons.restore_rounded),
                              onPressed: () => _restoreTask(t),
                            ),
                            IconButton(
                              tooltip: 'Delete forever',
                              icon: const Icon(Icons.delete_forever_rounded),
                              onPressed: () => _deleteTaskForever(t),
                            ),
                          ],
                        ),
                      )),
                const Divider(height: 24),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text('Discarded Signals', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                if (_signals.isEmpty)
                  const ListTile(title: Text('No discarded signals.'))
                else
                  ..._signals.map((s) => ListTile(
                        leading: const Icon(Icons.bolt_rounded),
                        title: Text(s.title),
                        subtitle: s.body == null ? null : Text(s.body!, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Restore',
                              icon: const Icon(Icons.restore_rounded),
                              onPressed: () => _restoreSignal(s),
                            ),
                            IconButton(
                              tooltip: 'Delete forever',
                              icon: const Icon(Icons.delete_forever_rounded),
                              onPressed: () => _deleteSignalForever(s),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
    );
  }
}
