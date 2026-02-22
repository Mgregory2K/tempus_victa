import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
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
  final SpeechToText _stt = SpeechToText();

  bool _isRecording = false;
  String? _activePath;

  // Live transcript captured while recording (offline-capable if device has offline language packs).
  String _liveTranscript = '';
  bool _sttInitialized = false;

  @override
  void dispose() {
    _stt.cancel();
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

  Future<void> _ensureSttReady() async {
    if (_sttInitialized) return;

    // If initialization fails (no service / restricted device), we still record audio.
    try {
      _sttInitialized = await _stt.initialize(
        onError: (e) {
          // Intentionally silent for baseline. Audio capture must still work.
        },
        onStatus: (s) {
          // no-op
        },
      );
    } catch (_) {
      _sttInitialized = false;
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

    // Reset transcript for this capture.
    _liveTranscript = '';

    // Start audio recording first (core capture must work even if STT fails).
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    // Start live transcription in parallel (best-effort).
    await _ensureSttReady();
    if (_sttInitialized) {
      try {
        await _stt.listen(
          onResult: (result) {
            // Keep the latest recognized words. We'll save the final value when recording ends.
            _liveTranscript = result.recognizedWords;
          },
          listenMode: ListenMode.dictation,
          partialResults: true,
        );
      } catch (_) {
        // Ignore STT issues; audio capture still succeeds.
      }
    }

    setState(() {
      _isRecording = true;
      _activePath = path;
    });
  }

  Future<void> _stopAndCreateTask() async {
    if (!_isRecording) return;

    // Stop transcription first (best-effort) so we finalize recognized words.
    try {
      if (_stt.isListening) {
        await _stt.stop();
      }
    } catch (_) {
      // ignore
    }

    final stoppedPath = await _recorder.stop();

    final path = stoppedPath ?? _activePath;
    setState(() {
      _isRecording = false;
      _activePath = null;
    });

    if (path == null || path.trim().isEmpty) return;

    // The task ID is derived from filename.
    final id = path.split(Platform.pathSeparator).last.split('.').first;

    final transcript = _liveTranscript.trim().isEmpty ? null : _liveTranscript.trim();
    final title = transcript == null
        ? 'Voice task'
        : TaskItem.titleFromTranscript(transcript, maxWords: 6);

    final task = TaskItem(
      id: id,
      createdAt: DateTime.now(),
      title: title,
      audioPath: path,
      transcript: transcript,
    );

    await TaskStore.upsert(task);

    if (!mounted) return;
    AppStateScope.of(context).bumpTasksVersion();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(transcript == null ? 'Task created (no transcript yet)' : 'Task created')),
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
