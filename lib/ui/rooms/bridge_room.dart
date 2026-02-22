import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_state_scope.dart';
import '../../core/task_item.dart';
import '../../core/task_store.dart';
import '../room_frame.dart';

class BridgeRoom extends StatefulWidget {
  final String roomName;
  const BridgeRoom({super.key, required this.roomName});

  @override
  State<BridgeRoom> createState() => _BridgeRoomState();
}

class _BridgeRoomState extends State<BridgeRoom> {
  final _recorder = AudioRecorder();

  bool _isRecording = false;
  String? _activePath;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<String> _nextAudioPath(String taskId) async {
    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${dir.path}/tempus/audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return '${audioDir.path}/$taskId.m4a';
  }

  String _defaultVoiceTitle(DateTime when, {Duration? duration}) {
    // Distinguishable immediately, even with no transcript.
    // Example: "Voice – 2/22 8:14 AM" or "Voice – 0:12 – 2/22 8:14 AM"
    final month = when.month;
    final day = when.day;

    int hour = when.hour;
    final minute = when.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;

    final ts = '$month/$day $hour:$minute $ampm';
    if (duration == null || duration.inMilliseconds <= 0) return 'Voice – $ts';

    final dur = _fmtDuration(duration);
    return 'Voice – $dur – $ts';
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    final ss = s.toString().padLeft(2, '0');
    return '$m:$ss';
  }

  Future<int?> _probeDurationMs(String path) async {
    try {
      final player = AudioPlayer();
      await player.setFilePath(path);
      final dur = player.duration;
      await player.dispose();
      return dur?.inMilliseconds;
    } catch (_) {
      return null;
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    final ok = await _recorder.hasPermission();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required.')),
      );
      return;
    }

    final taskId = const Uuid().v4();
    final path = await _nextAudioPath(taskId);

    // Core capture must succeed. Keep this simple and reliable.
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    setState(() {
      _isRecording = true;
      _activePath = path;
    });
  }

  Future<void> _stopAndCreateTask() async {
    if (!_isRecording) return;

    final createdAt = DateTime.now();

    final stoppedPath = await _recorder.stop();
    final path = stoppedPath ?? _activePath;

    setState(() {
      _isRecording = false;
      _activePath = null;
    });

    if (path == null || path.trim().isEmpty) return;

    // Guardrail: never create an empty task.
    final f = File(path);
    if (!await f.exists()) return;

    final bytes = await f.length();
    if (bytes < 2048) {
      // Too small to be a real recording (interrupted / lost focus / 0s).
      try {
        await f.delete();
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording was interrupted (no audio captured). Hold to retry.')),
      );
      return;
    }

    // Task ID is derived from filename.
    final id = path.split(Platform.pathSeparator).last.split('.').first;

    final durMs = await _probeDurationMs(path);
    final dur = durMs == null ? null : Duration(milliseconds: durMs);
    final title = _defaultVoiceTitle(createdAt, duration: dur);

    final task = TaskItem(
      id: id,
      createdAt: createdAt,
      title: title,
      audioPath: path,
      audioDurationMs: durMs,
      transcript: null,
    );

    await TaskStore.upsert(task);

    if (!mounted) return;
    AppStateScope.of(context).bumpTasksVersion();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Task created'),
        action: SnackBarAction(
          label: 'Rename',
          onPressed: () => _renameTask(task),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return RoomFrame(
      title: widget.roomName,
      child: Center(
        child: Text(
          _isRecording ? 'Recording…' : 'Bridge',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      floating: GestureDetector(
        onLongPressStart: (_) => _startRecording(),
        onLongPressEnd: (_) => _stopAndCreateTask(),
        child: FloatingActionButton.small(
          heroTag: 'bridge_mic',
          onPressed: () {},
          child: Icon(_isRecording ? Icons.mic : Icons.mic_none_rounded),
        ),
      ),
    );
  }
}
