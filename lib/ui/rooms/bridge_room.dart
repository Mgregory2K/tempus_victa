import 'package:flutter/material.dart';

import '../../core/app_state_scope.dart';
import '../../core/metrics_store.dart';
import '../../core/task_item.dart';
import '../../core/task_store.dart';
import '../../core/twin_plus/twin_event.dart';
import '../../core/twin_plus/twin_plus_scope.dart';
import '../../services/voice/voice_service.dart';
import '../room_frame.dart';

class BridgeRoom extends StatefulWidget {
  final String roomName;
  const BridgeRoom({super.key, required this.roomName});

  @override
  State<BridgeRoom> createState() => _BridgeRoomState();
}

class _BridgeRoomState extends State<BridgeRoom> {
  bool _voiceReady = false;
  bool _listening = false;
  String _live = '';

  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  Future<void> _initVoice() async {
    final ok = await VoiceService.instance.init();
    if (!mounted) return;
    setState(() => _voiceReady = ok);
  }

  Future<void> _startListen() async {
    if (!_voiceReady) return;
    setState(() {
      _listening = true;
      _live = '';
    });

    await VoiceService.instance.start(
      onPartial: (p) {
        if (!mounted) return;
        setState(() => _live = p);
      },
    );
  }

  Future<void> _stopAndCreateTask() async {
    if (!_listening) return;
    final res = await VoiceService.instance.stop(finalTranscript: _live);
    if (!mounted) return;

    setState(() => _listening = false);

    final transcript = res.transcript.trim();
    if (transcript.isEmpty) return;

    final now = DateTime.now();
    final task = TaskItem(
      id: now.microsecondsSinceEpoch.toString(),
      createdAt: now,
      title: TaskItem.titleFromTranscript(transcript, maxWords: 6),
      transcript: transcript,
      audioDurationMs: res.durationMs,
      audioPath: null,
      projectId: null,
    );

    final tasks = await TaskStore.load();
    await TaskStore.save([task, ...tasks]);
    AppStateScope.of(context).bumpTasksVersion();

    await MetricsStore.inc(TvMetrics.tasksCreatedVoice);

    final kernel = TwinPlusScope.of(context);
    kernel.observe(
      TwinEvent.actionPerformed(surface: 'bridge', action: 'task_created_voice', entityType: 'task', entityId: task.id),
    );

    // Jump to Tasks (same behavior as before).
    if (!mounted) return;
    AppStateScope.of(context).setSelectedModule('tasks');
  }

  @override
  Widget build(BuildContext context) {
    return RoomFrame(
      title: widget.roomName,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Bridge', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_listening ? 'Listening…' : 'Quick capture', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      _live.trim().isEmpty ? 'Tap the mic and speak.' : _live.trim(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: !_voiceReady
                                ? null
                                : (_listening ? _stopAndCreateTask : _startListen),
                            icon: Icon(_listening ? Icons.stop : Icons.mic),
                            label: Text(_listening ? 'Stop + Create Task' : 'Voice Task'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
