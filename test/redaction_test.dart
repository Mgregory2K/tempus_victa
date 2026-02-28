import 'package:test/test.dart';
import 'package:tempus_victa/services/redaction/redaction.dart';

void main() {
  group('Redactor', () {
    test('redacts email and phone in body', () {
      final r = Redactor();
      final item = {
        'body': 'Contact me at alice@example.com or +1 (555) 123-4567.'
      };
      final res = r.redactItem(item);
      final body = res.payload['body'] as String;
      expect(body.contains('alice@example.com'), isFalse);
      expect(body.contains('+1 (555) 123-4567'), isFalse);
      expect(res.redactedFields, contains('body'));
    });

    test('redacts attachments field when present', () {
      final r = Redactor();
      final item = {
        'title': 'Invoice',
        'attachments': ['file1.pdf']
      };
      final res = r.redactItem(item);
      expect(res.payload['attachments'], equals('[REDACTED_ATTACHMENT]'));
      expect(res.redactedFields, contains('attachments'));
    });

    test('does not alter clean text', () {
      final r = Redactor();
      final item = {'body': 'Buy milk tomorrow'};
      final res = r.redactItem(item);
      expect(res.payload['body'], equals('Buy milk tomorrow'));
      expect(res.redactedFields.isEmpty, isTrue);
    });
  });
}
