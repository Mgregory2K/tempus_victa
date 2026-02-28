// Minimal ingestion module for Tempus Victa
import 'dart:async';
import 'dart:convert';
import 'dart:math';

class DoctrineInput {
  final String inputId;
  final String source; // voice|text|notification|share|manual|import
  final String raw;
  final String normalizedText;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  DoctrineInput({
    required this.inputId,
    required this.source,
    required this.raw,
    required this.normalizedText,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
  })  : metadata = metadata ?? {},
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'input_id': inputId,
        'source': source,
        'raw': raw,
        'normalized_text': normalizedText,
        'metadata': metadata,
        'timestamp': timestamp.toIso8601String(),
      };
}

String _simpleUuid() {
  final r = Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

String _normalizeText(String s) {
  var out = s.trim().toLowerCase();
  out = out.replaceAll(RegExp(r'\s+'), ' ');
  // simple filler removal example
  out = out.replaceAll(RegExp(r'\b(um|uh|like|you know)\b'), '');
  out = out.replaceAll(RegExp(r"[^\w\s@:/\-']"), '');
  out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
  return out;
}

abstract class Ingestor {
  Future<DoctrineInput> ingest(String raw, {Map<String, dynamic>? metadata});
}

class TextIngestor implements Ingestor {
  final String sourceLabel;
  TextIngestor({this.sourceLabel = 'text'});

  @override
  Future<DoctrineInput> ingest(String raw,
      {Map<String, dynamic>? metadata}) async {
    final normalized = _normalizeText(raw);
    final input = DoctrineInput(
      inputId: 'in:${_simpleUuid()}',
      source: sourceLabel,
      raw: raw,
      normalizedText: normalized,
      metadata: metadata,
    );
    // In a full implementation, write ingestion record to Local Store and provenance.
    return input;
  }
}

class VoiceIngestor implements Ingestor {
  final String sourceLabel;
  VoiceIngestor({this.sourceLabel = 'voice'});

  // `raw` here is assumed to be a path or a base64-encoded audio placeholder in this minimal example
  @override
  Future<DoctrineInput> ingest(String raw,
      {Map<String, dynamic>? metadata}) async {
    // Simulated transcription: in real app integrate with on-device STT or queued transcription service
    final transcript = await _transcribeMock(raw);
    final normalized = _normalizeText(transcript);
    final input = DoctrineInput(
      inputId: 'in:${_simpleUuid()}',
      source: sourceLabel,
      raw: raw,
      normalizedText: normalized,
      metadata: metadata,
    );
    return input;
  }

  Future<String> _transcribeMock(String raw) async {
    // Simulate small async delay
    await Future.delayed(Duration(milliseconds: 50));
    // If raw looks like base64 or path, produce a deterministic pseudo-transcript
    if (raw.length > 100 || raw.contains('/')) {
      return 'transcribed voice input';
    }
    return raw; // allow passing text in tests
  }
}

class IngestionService {
  final Map<String, Ingestor> _ingestors = {};

  void registerIngestor(String key, Ingestor ingestor) {
    _ingestors[key] = ingestor;
  }

  Future<DoctrineInput> ingestWith(String key, String raw,
      {Map<String, dynamic>? metadata}) async {
    final ing = _ingestors[key];
    if (ing == null) throw StateError('No ingestor registered for $key');
    final input = await ing.ingest(raw, metadata: metadata);
    return input;
  }
}
