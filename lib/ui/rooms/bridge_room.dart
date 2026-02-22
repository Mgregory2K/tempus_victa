import 'dart:io';

import 'package:flutter/material.dart';
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

    final stoppedPath = await _recorder.stop();

    final path = stoppedPath ?? _activePath;
    setState(() {
      _isRecording = false;
      _activePath = null;
    });

    if (path == null || path.trim().isEmpty) return;

    // The task ID is derived from filename.
    final id = path.split(Platform.pathSeparator).last.split('.').first;

    final task = TaskItem(
      id: id,
      createdAt: DateTime.now(),
      title: 'Voice task',
      audioPath: path,
      transcript: null,
    );

    await TaskStore.upsert(task);

    if (!mounted) return;
    AppStateScope.of(context).bumpTasksVersion();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task created')),
    );
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
