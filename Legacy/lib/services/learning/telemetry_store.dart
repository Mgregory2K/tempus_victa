// lib/services/learning/telemetry_store.dart
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class TelemetryStore {
  TelemetryStore._();
  static final TelemetryStore instance = TelemetryStore._();

  bool _initialized = false;
  late Directory _learningDir;
  late File _eventsFile;

  bool get isInitialized => _initialized;
  File get eventsFile => _eventsFile;

  Future<void> init() async {
    if (_initialized) return;

    final docs = await getApplicationDocumentsDirectory();
    _learningDir = Directory('${docs.path}/learning');
    if (!await _learningDir.exists()) {
      await _learningDir.create(recursive: true);
    }

    _eventsFile = File('${_learningDir.path}/learning_events.jsonl');
    if (!await _eventsFile.exists()) {
      await _eventsFile.create(recursive: true);
    }

    _initialized = true;
  }

  Future<void> append(Map<String, dynamic> payload) async {
    if (!_initialized) await init();
    final line = jsonEncode(payload);
    await _eventsFile.writeAsString('$line\n', mode: FileMode.append, flush: true);
  }
}
