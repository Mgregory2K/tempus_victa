import 'package:flutter/services.dart';

class NativeSpeechService {
  static const MethodChannel _channel =
      MethodChannel('tempus.native.speech');

  static Future<String?> startListening() async {
    try {
      final result = await _channel.invokeMethod<String>('startSpeech');
      return result;
    } catch (e) {
      return null;
    }
  }
}