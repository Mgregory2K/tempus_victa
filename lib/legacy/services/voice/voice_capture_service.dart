import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Simple, local speech-to-text wrapper.
/// - Requests RECORD_AUDIO permission at runtime
/// - Provides partial and final results
class VoiceCaptureService {
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _ready = false;

  bool get isListening => _stt.isListening;

  Future<bool> ensureReady() async {
    if (_ready) return true;

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) return false;

    try {
      _ready = await _stt.initialize(
        onError: (e) => debugPrint('STT error: $e'),
        onStatus: (s) => debugPrint('STT status: $s'),
      );
    } catch (e) {
      debugPrint('STT init failed: $e');
      _ready = false;
    }

    return _ready;
  }

  Future<bool> start({
    required ValueChanged<String> onPartial,
    required ValueChanged<String> onFinal,
  }) async {
    final ok = await ensureReady();
    if (!ok) return false;

    await _stt.listen(
      onResult: (r) {
        final text = r.recognizedWords.trim();
        if (text.isEmpty) return;

        if (r.finalResult) {
          onFinal(text);
        } else {
          onPartial(text);
        }
      },
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      cancelOnError: true,
    );

    return true;
  }

  Future<void> stop() async {
    if (_stt.isListening) {
      await _stt.stop();
    }
  }

  Future<void> cancel() async {
    if (_stt.isListening) {
      await _stt.cancel();
    }
  }
}
