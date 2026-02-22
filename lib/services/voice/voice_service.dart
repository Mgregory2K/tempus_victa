// Tempus Vista rebuild - generated 2026-02-21
// Local-first, Android-first.


import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

typedef VoicePartialCallback = void Function(String words);

class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final SpeechToText _stt = SpeechToText();
  bool _available = false;
  bool get available => _available;
  bool get listening => _stt.isListening;

  String _lastWords = '';
  String get lastWords => _lastWords;

  Future<void> init() async {
    if (_available) return;
    _available = await _stt.initialize();
  }

  Future<void> startListening({
    Duration listenFor = const Duration(minutes: 2),
    VoicePartialCallback? onPartial,
  }) async {
    await init();
    if (!_available) return;

    _lastWords = '';
    await _stt.listen(
      listenFor: listenFor,
      onResult: (r) {
        _lastWords = r.recognizedWords;
        if (onPartial != null) onPartial(_lastWords);
      },
      cancelOnError: true,
      partialResults: true,
    );
  }

  Future<String> stopAndGetFinal() async {
    if (_stt.isListening) {
      await _stt.stop();
    }
    return _lastWords.trim();
  }

  /// Stops the current listening session (if any).
  Future<void> stop() async {
    if (_stt.isListening) {
      await _stt.stop();
    }
  }

  Future<String> listenOnce({Duration listenFor = const Duration(seconds: 18)}) async {
    await startListening(listenFor: listenFor);
    await Future.delayed(listenFor);
    return stopAndGetFinal();
  }
}
