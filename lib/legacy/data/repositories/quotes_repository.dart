import 'package:drift/drift.dart';
import 'package:mobile/data/db/app_db.dart';

// Placeholder class until we build the real table
class Quote {
  final int id;
  final String text;
  final String author;
  const Quote({required this.id, required this.text, required this.author});
}

class QuotesRepository {
  final AppDatabase _db;

  QuotesRepository(this._db);

  Stream<List<Quote>> watchQuotes() {
    return Stream.value([
      const Quote(id: 1, text: 'The only thing we have to fear is fear itself.', author: 'Franklin D. Roosevelt'),
      const Quote(id: 2, text: 'Be the change that you wish to see in the world.', author: 'Mahatma Gandhi'),
    ]);
  }
}
