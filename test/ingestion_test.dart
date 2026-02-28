import 'package:test/test.dart';
import 'package:tempus_victa/services/ingestion/ingestion.dart';

void main() {
  group('Ingestion module', () {
    test('TextIngestor normalizes text', () async {
      final t = TextIngestor();
      final input = await t.ingest('  Buy DOG food  tomorrow!! ');
      expect(input.normalizedText, contains('buy'));
      expect(input.normalizedText, contains('dog'));
    });

    test('VoiceIngestor transcribes mock input', () async {
      final v = VoiceIngestor();
      final input = await v.ingest('this is a voice sample');
      expect(input.normalizedText, contains('voice'));
    });

    test('IngestionService routes to registered ingestors', () async {
      final s = IngestionService();
      s.registerIngestor('text', TextIngestor());
      final input = await s.ingestWith('text', 'Make coffee at 9am');
      expect(input.source, equals('text'));
    });
  });
}
