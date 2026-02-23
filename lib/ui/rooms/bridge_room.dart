import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/app_state_scope.dart';
import '../../core/metrics_store.dart';
import '../../core/task_item.dart';
import '../../core/task_store.dart';
import '../room_frame.dart';
import '../theme/tempus_ui.dart';

class BridgeRoom extends StatefulWidget {
  final String roomName;
  const BridgeRoom({super.key, required this.roomName});

  @override
  State<BridgeRoom> createState() => _BridgeRoomState();
}

class _BridgeRoomState extends State<BridgeRoom> {
  final AudioRecorder _recorder = AudioRecorder();
  final SpeechToText _stt = SpeechToText();

  bool _isRecording = false;
  String? _activePath;
  String _liveTranscript = '';

  Map<String, int> _metrics = const {};

  @override
  void initState() {
    super.initState();
    _loadMetrics();
    _initStt();
  }

  Future<void> _loadMetrics() async {
    final m = await MetricsStore.load();
    if (!mounted) return;
    setState(() => _metrics = m);
  }

  Future<void> _initStt() async {
    try {
      await _stt.initialize();
    } catch (_) {
      // STT is best-effort; recording still works.
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}${Platform.pathSeparator}voice');
    if (!folder.existsSync()) folder.createSync(recursive: true);

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final path = '${folder.path}${Platform.pathSeparator}$id.m4a';

    try {
      _liveTranscript = '';
      setState(() {
        _isRecording = true;
        _activePath = path;
      });

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      // Best-effort live transcription.
      if (await _stt.hasPermission) {
        await _stt.listen(
          onResult: (r) => setState(() => _liveTranscript = r.recognizedWords),
          listenMode: ListenMode.dictation,
        );
      }
    } catch (_) {
      setState(() {
        _isRecording = false;
        _activePath = null;
      });
    }
  }

  Future<void> _stopAndCreateTask() async {
    if (!_isRecording) return;

    try {
      if (_stt.isListening) await _stt.stop();
    } catch (_) {}

    final stoppedPath = await _recorder.stop();
    final path = stoppedPath ?? _activePath;

    setState(() {
      _isRecording = false;
      _activePath = null;
    });

    if (path == null || path.trim().isEmpty) return;

    final id = path.split(Platform.pathSeparator).last.split('.').first;

    final transcript = _liveTranscript.trim().isEmpty ? null : _liveTranscript.trim();
    final title = transcript == null ? 'Voice task' : TaskItem.titleFromTranscript(transcript, maxWords: 6);

    final task = TaskItem(
      id: id,
      createdAt: DateTime.now(),
      title: title,
      audioPath: path,
      transcript: transcript,
    );

    await TaskStore.upsert(task);
    await MetricsStore.bump(MetricKeys.tasksCreatedVoice);
    await _loadMetrics();

    if (!mounted) return;
    AppStateScope.of(context).bumpTasksVersion();

    // Magic: no explanation. Just confirmation.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Captured')));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final signals = _metrics[MetricKeys.signalsIngested] ?? 0;
    final tasks = (_metrics[MetricKeys.tasksCreatedManual] ?? 0) + (_metrics[MetricKeys.tasksCreatedVoice] ?? 0);
    final web = _metrics[MetricKeys.webSearches] ?? 0;
    final ai = _metrics[MetricKeys.aiReplies] ?? 0;

    return RoomFrame(
      title: widget.roomName,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: ListView(
          children: [
            Text(
              'Welcome back.',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 14 * 2 - 10) / 2,
                  child: TempusMetricTile(label: 'Signals logged', value: '$signals', icon: Icons.radar),
                ),
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 14 * 2 - 10) / 2,
                  child: TempusMetricTile(label: 'Tasks captured', value: '$tasks', icon: Icons.check_circle_outline),
                ),
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 14 * 2 - 10) / 2,
                  child: TempusMetricTile(label: 'Web lookups', value: '$web', icon: Icons.public),
                ),
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 14 * 2 - 10) / 2,
                  child: TempusMetricTile(label: 'AI assists', value: '$ai', icon: Icons.auto_awesome),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TempusCard(
              child: Row(
                children: [
                  Icon(_isRecording ? Icons.mic : Icons.mic_none_rounded, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isRecording ? 'Listening…' : 'Hold mic to capture a voice task',
                      style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TempusPill(text: _isRecording ? 'Recording' : 'Ready'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TempusCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface)),
                  const SizedBox(height: 10),
                  Text(
                    'Signals flow into Signal Bay. If something needs action, promote it to a Task. If it’s just knowledge, acknowledge it and keep it logged.',
                    style: TextStyle(color: cs.onSurfaceVariant, height: 1.25),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floating: GestureDetector(
        onLongPressStart: (_) => _startRecording(),
        onLongPressEnd: (_) => _stopAndCreateTask(),
        child: FloatingActionButton(
          heroTag: 'bridge_mic',
          onPressed: () {},
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          child: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_none_rounded),
        ),
      ),
    );
  }
}


class _WelcomeBlock extends StatelessWidget {
  final bool isRecording;
  const _WelcomeBlock({required this.isRecording});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TempusCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(isRecording ? Icons.mic : Icons.mic_none, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.onSurface)),
                const SizedBox(height: 2),
                Text(
                  isRecording ? 'Listening… (release to save)' : 'Press and hold the mic to capture a voice task.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
