import 'package:flutter_test/flutter_test.dart';
import 'package:tempus_victa/services/db/db_provider.dart';
import 'package:tempus_victa/services/lexicon/lexicon.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('lexicon observe and suggest', () async {
    await DatabaseProvider.init(dbPath: ':memory:');
    // Ensure migrations ran creating lexicon_entries
    LexiconService.observePhrase('buy milk');
    LexiconService.observePhrase('buy bread');
    LexiconService.observePhrase('buy milk');

    final suggestions = LexiconService.suggest('buy');
    expect(suggestions.isNotEmpty, true);
    expect(suggestions.first.phrase.startsWith('buy'), true);
  });
}
