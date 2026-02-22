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

  final AudioPlayer _player = AudioPlayer();
  String? _playingTaskId;
  bool _loadingPlayback = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

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
            itemBuilder: (context, i) => _taskTile(context, tasks[i]),
          );
        },
      ),
    );
  }

  Widget _taskTile(BuildContext context, TaskItem t) {
    final hasAudio = t.audioPath != null && t.audioPath!.isNotEmpty;
    final created = _fmtCreated(t.createdAt);

    final dur = (t.audioDurationMs == null || t.audioDurationMs! <= 0)
        ? null
        : _fmtDuration(Duration(milliseconds: t.audioDurationMs!));

    final subtitle = hasAudio
        ? (dur == null ? 'Voice • $created' : 'Voice • $dur • $created')
        : (t.transcript?.trim().isNotEmpty == true ? 'Text • $created' : created);

    final isThisPlaying = _playingTaskId == t.id;

    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, psSnap) {
        final playing = psSnap.data?.playing ?? false;
        final showPause = isThisPlaying && playing;

        return ListTile(
          leading: Icon(hasAudio ? Icons.mic_rounded : Icons.check_box_outline_blank_rounded),
          title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasAudio)
                IconButton(
                  tooltip: showPause ? 'Pause' : 'Play',
                  onPressed: _loadingPlayback ? null : () => _togglePlay(t),
                  icon: _loadingPlayback && isThisPlaying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(showPause ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
              IconButton(
                tooltip: 'Rename',
                onPressed: () => _renameTask(t),
                icon: const Icon(Icons.edit_rounded),
              ),
              IconButton(
                tooltip: 'Details',
                onPressed: () => _openTask(context, t),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          onTap: () {
            // Busy-user default: tap row plays if it's a voice task, else opens details.
            if (hasAudio) {
              _togglePlay(t);
            } else {
              _openTask(context, t);
            }
          },
        );
      },
    );
  }

  Future<void> _togglePlay(TaskItem t) async {
    final path = t.audioPath;
    if (path == null || path.isEmpty) return;

    final f = File(path);
    if (!await f.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio file not found.')),
      );
      return;
    }

    setState(() {
      _loadingPlayback = true;
    });

    try {
      final isSame = _playingTaskId == t.id;

      if (isSame && _player.playing) {
        await _player.pause();
        return;
      }

      if (!isSame) {
        _playingTaskId = t.id;
        await _player.setFilePath(path);
      }

      await _player.play();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to play audio.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingPlayback = false;
        });
      }
    }
  }

  Future<void> _renameTask(TaskItem task) async {
    final controller = TextEditingController(text: task.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename task'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => Navigator.pop(context, controller.text.trim()),
            decoration: const InputDecoration(
              hintText: 'Enter a title',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    final trimmed = newTitle?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    final updated = task.copyWith(title: trimmed);
    await TaskStore.upsert(updated);

    if (!mounted) return;
    AppStateScope.of(context).bumpTasksVersion();
  }

  Future<void> _openTask(BuildContext context, TaskItem task) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _TaskDetail(
        task: task,
        onRename: (newTitle) async {
          final updated = task.copyWith(title: newTitle);
          await TaskStore.upsert(updated);
          if (!context.mounted) return;
          AppStateScope.of(context).bumpTasksVersion();
        },
      ),
    );
  }

  String _fmtCreated(DateTime dt) {
    final d = dt.toLocal();
    int hour = d.hour;
    final minute = d.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return '$hour:$minute $ampm';
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    final ss = s.toString().padLeft(2, '0');
    return '$m:$ss';
  }
}

class _TaskDetail extends StatefulWidget {
  final TaskItem task;
  final Future<void> Function(String newTitle) onRename;
  const _TaskDetail({required this.task, required this.onRename});

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Rename',
                  onPressed: _renameFromDetail,
                  icon: const Icon(Icons.edit_rounded),
                ),
              ],
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
                  (t.transcript == null || t.transcript!.trim().isEmpty) ? '—' : t.transcript!,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameFromDetail() async {
    final controller = TextEditingController(text: widget.task.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename task'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => Navigator.pop(context, controller.text.trim()),
            decoration: const InputDecoration(hintText: 'Enter a title'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
          ],
        );
      },
    );

    final trimmed = newTitle?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    await widget.onRename(trimmed);
    if (!mounted) return;
    Navigator.pop(context);
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
