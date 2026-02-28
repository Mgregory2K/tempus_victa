import 'package:test/test.dart';
import 'package:tempus_victa/services/consent/consent.dart';

void main() {
  group('ConsentManager', () {
    test('grant and revoke consent', () {
      final m = ConsentManager();
      final rec = m.grant(scope: 'ai:redacted', via: 'test');
      expect(rec.granted, isTrue);
      final loaded = m.getConsent('ai:redacted');
      expect(loaded, isNotNull);
      expect(loaded!.granted, isTrue);
      m.revoke('ai:redacted');
      final after = m.getConsent('ai:redacted');
      expect(after, isNotNull);
      expect(after!.granted, isFalse);
    });
  });
}
