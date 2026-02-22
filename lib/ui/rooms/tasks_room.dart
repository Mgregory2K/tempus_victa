import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/app_state_scope.dart';
import '../../core/task_item.dart';
import '../../core/task_store.dart';
import '../room_frame.dart';

class TasksRoom extends StatefulWidget {
  final String roomName;
  const TasksRoom({super.key, required this.roomName});

  @override
  State<TasksRoom> createState() => _TasksRoomState();
}

class _TasksRoomState extends State<TasksRoom> {
  Future<List<TaskItem>> _load() => TaskStore.load();

  @override
  Widget build(BuildContext context) {
    // Reading this makes the widget rebuild whenever tasksVersion changes.
    final _ = AppStateScope.of(context).tasksVersion;

    return RoomFrame(
      title: widget.roomName,
      child: FutureBuilder<List<TaskItem>>(
        future: _load(),
        builder: (context, snap) {
          final tasks = snap.data ?? const <TaskItem>[];

          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (tasks.isEmpty) {
            return const Center(child: Text('No tasks yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final t = tasks[i];
              final hasAudio = t.audioPath != null && t.audioPath!.isNotEmpty;
              final subtitle = hasAudio
                  ? 'Voice capture'
                  : (t.transcript?.trim().isNotEmpty == true
                      ? 'Text'
                      : '');

              return ListTile(
                leading: Icon(hasAudio ? Icons.mic_rounded : Icons.check_box_outline_blank_rounded),
                title: Text(t.title),
                subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openTask(context, t),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openTask(BuildContext context, TaskItem task) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _TaskDetail(task: task),
    );
  }
}

class _TaskDetail extends StatefulWidget {
  final TaskItem task;
  const _TaskDetail({required this.task});

  @override
  State<_TaskDetail> createState() => _TaskDetailState();
}

class _TaskDetailState extends State<_TaskDetail> {
  final _player = AudioPlayer();
  bool _ready = false;
  bool _transcriptOpen = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final path = widget.task.audioPath;
    if (path != null && path.isNotEmpty && await File(path).exists()) {
      await _player.setFilePath(path);
      setState(() => _ready = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Created: ${t.createdAt.toLocal()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (_ready) _playerControls(context) else const Text('No audio attached.'),
            const SizedBox(height: 12),
            Divider(color: Theme.of(context).dividerColor),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Transcript'),
              subtitle: Text(
                (t.transcript == null || t.transcript!.trim().isEmpty)
                    ? 'Not transcribed yet.'
                    : 'Tap to view',
              ),
              trailing: Icon(_transcriptOpen ? Icons.expand_less : Icons.expand_more),
              onTap: () => setState(() => _transcriptOpen = !_transcriptOpen),
            ),
            if (_transcriptOpen)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  (t.transcript == null || t.transcript!.trim().isEmpty)
                      ? '—'
                      : t.transcript!,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _playerControls(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snap) {
        final playing = snap.data?.playing ?? false;

        return Row(
          children: [
            IconButton.filled(
              onPressed: () async {
                if (playing) {
                  await _player.pause();
                } else {
                  await _player.play();
                }
              },
              icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StreamBuilder<Duration?>(
                stream: _player.durationStream,
                builder: (context, dSnap) {
                  final dur = dSnap.data ?? Duration.zero;
                  return StreamBuilder<Duration>(
                    stream: _player.positionStream,
                    builder: (context, pSnap) {
                      final pos = pSnap.data ?? Duration.zero;
                      final max = dur.inMilliseconds == 0 ? 1 : dur.inMilliseconds;
                      final v = (pos.inMilliseconds / max).clamp(0.0, 1.0);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(value: v),
                          const SizedBox(height: 4),
                          Text('${_fmt(pos)} / ${_fmt(dur)}', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    final ss = s.toString().padLeft(2, '0');
    return '$m:$ss';
  }
}
