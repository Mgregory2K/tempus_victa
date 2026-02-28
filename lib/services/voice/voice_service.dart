import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Result of a single voice capture.
class VoiceResult {
  final String transcript;
  final String preview6;
  final int durationMs;

  /// Local path to recorded audio (m4a) when available.
  /// STT-priority mode returns null here; audio capture is reintroduced later using a single-mic-owner design.
  final String? audioPath;

  const VoiceResult({
    required this.transcript,
    required this.preview6,
    required this.durationMs,
    required this.audioPath,
  });
}

/// Single, shared voice pipeline for Tempus.
/// STT-Priority Mode (reliability first):
/// - Local-only
/// - Uses SpeechToText for transcript
/// - Does NOT record audio concurrently (avoids Android mic contention)
class VoiceService {
  static final VoiceService instance = VoiceService._internal();
  VoiceService._internal();

  final stt.SpeechToText _stt = stt.SpeechToText();

  bool _ready = false;
  DateTime? _started;

  String _latestWords = '';
  String? _lastError;
  String? _lastStatus;

  bool get isReady => _ready;
  bool get isListening => _stt.isListening;
  String? get lastError => _lastError;
  String? get lastStatus => _lastStatus;

  Future<bool> init() async {
    if (_ready) return true;
    try {
      _ready = await _stt.initialize(
        onError: (e) => _lastError = e.errorMsg,
        onStatus: (s) => _lastStatus = s,
      );
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  Future<bool> start({required void Function(String partial) onPartial}) async {
    final ok = await init();
    if (!ok) return false;

    _started = DateTime.now();
    _latestWords = '';
    _lastError = null;
    _lastStatus = null;

    // Some versions expose hasPermission as Future<bool>.
    bool hasPerm = true;
    try {
      hasPerm = await _stt.hasPermission;
    } catch (_) {
      hasPerm = true;
    }
    if (!hasPerm) return false;

    String? localeId;
    try {
      final sys = await _stt.systemLocale();
      localeId = sys?.localeId;
    } catch (_) {
      localeId = null;
    }

    try {
      await _stt.listen(
        localeId: localeId,
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        onResult: (r) {
          final words = r.recognizedWords;
          if (words.trim().isNotEmpty) _latestWords = words;
          onPartial(words);
        },
        listenFor: const Duration(seconds: 25),
        pauseFor: const Duration(seconds: 3),
      );
    } catch (_) {
      return false;
    }

    return _stt.isListening;
  }

  Future<VoiceResult> stop({required String finalTranscript}) async {
    try {
      await _stt.stop();
    } catch (_) {}

    final end = DateTime.now();
    final duration = _started == null ? 0 : end.difference(_started!).inMilliseconds;

    final cleaned = (finalTranscript.trim().isNotEmpty ? finalTranscript.trim() : _latestWords.trim());
    final words = cleaned.isEmpty
        ? <String>[]
        : cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final preview = words.take(6).join(' ');

    return VoiceResult(
      transcript: cleaned,
      preview6: preview,
      durationMs: duration,
      audioPath: null,
    );
  }
}
