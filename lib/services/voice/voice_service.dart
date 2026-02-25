import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Result of a single voice capture.
class VoiceResult {
  final String transcript;
  final String preview6;
  final int durationMs;

  const VoiceResult({
    required this.transcript,
    required this.preview6,
    required this.durationMs,
  });
}

/// Single, shared voice pipeline for Tempus.
/// - Local-only
/// - No persistence here (rooms/stores decide what to keep)
class VoiceService {
  static final VoiceService instance = VoiceService._internal();
  VoiceService._internal();

  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _ready = false;
  DateTime? _started;

  bool get isReady => _ready;
  bool get isListening => _stt.isListening;

  Future<bool> init() async {
    if (_ready) return true;
    try {
      _ready = await _stt.initialize();
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  Future<void> start({required void Function(String partial) onPartial}) async {
    final ok = await init();
    if (!ok) return;

    _started = DateTime.now();
    await _stt.listen(
      onResult: (r) {
        onPartial(r.recognizedWords);
      },
    );
  }

  Future<VoiceResult> stop({required String finalTranscript}) async {
    await _stt.stop();
    final end = DateTime.now();
    final duration = _started == null ? 0 : end.difference(_started!).inMilliseconds;

    final cleaned = finalTranscript.trim();
    final words = cleaned.isEmpty
        ? <String>[]
        : cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final preview = words.take(6).join(' ');

    return VoiceResult(
      transcript: cleaned,
      preview6: preview,
      durationMs: duration,
    );
  }
}
