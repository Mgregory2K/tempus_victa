import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/app_state_scope.dart';
import '../../data/tasks/task_model.dart';

class TaskDetailSheet extends StatefulWidget {
  final TaskModel task;

  const TaskDetailSheet({super.key, required this.task});

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  final AudioPlayer _player = AudioPlayer();
  bool _loading = false;
  bool _ready = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _ensureLoaded() async {
    if (_ready) return;
    final path = widget.task.audioPath;
    if (path == null) return;
    final f = File(path);
    if (!await f.exists()) return;

    setState(() => _loading = true);
    try {
      await _player.setFilePath(path);
      _ready = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final t = widget.task;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Task',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                icon: Icon(t.isCompleted ? Icons.check_circle : Icons.circle_outlined),
                onPressed: () => app.toggleComplete(t.id),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            t.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),

          if (t.audioPath != null) ...[
            const Divider(),
            Row(
              children: [
                _loading
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: StreamBuilder<PlayerState>(
                          stream: _player.playerStateStream,
                          builder: (context, snap) {
                            final playing = snap.data?.playing ?? false;
                            return Icon(playing ? Icons.pause : Icons.play_arrow_rounded);
                          },
                        ),
                        onPressed: () async {
                          await _ensureLoaded();
                          if (!_ready) return;
                          final playing = _player.playing;
                          if (playing) {
                            await _player.pause();
                          } else {
                            await _player.play();
                          }
                        },
                      ),
                Expanded(
                  child: StreamBuilder<Duration?>(
                    stream: _player.durationStream,
                    builder: (context, snap) {
                      final d = snap.data;
                      final txt = d == null ? 'Voice capture' : 'Duration: ${d.inSeconds}s';
                      return Text(txt);
                    },
                  ),
                ),
              ],
            ),
          ],

          const Divider(),
          ExpansionTile(
            title: const Text('Transcript'),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  t.transcript ?? 'Not transcribed yet.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),

          ExpansionTile(
            title: const Text('Metadata'),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'source: ${t.source}\ncreatedAt: ${DateTime.fromMillisecondsSinceEpoch(t.createdAtEpochMs)}\naudioPath: ${t.audioPath ?? '(none)'}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
