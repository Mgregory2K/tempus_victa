import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';


/// Simple local-first store for the Quote Board.
///
/// Lifecycle management:
/// - Caps stored quotes to [_maxQuotes] to keep the file from growing forever.
/// - When saving, trims oldest items first.
class QuoteBoardStore {
  static const String _fileName = 'quote_board.json';
  static const int _maxQuotes = 500;

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<List<QuoteEntry>> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return <QuoteEntry>[];
      final raw = await f.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <QuoteEntry>[];
      return decoded
          .whereType<Map>()
          .map((m) => QuoteEntry.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false);
    } catch (_) {
      return <QuoteEntry>[];
    }
  }

  static Future<void> save(List<QuoteEntry> entries) async {
    final trimmed = _trim(entries);
    final f = await _file();
    await f.writeAsString(jsonEncode(trimmed.map((e) => e.toJson()).toList(growable: false)));
  }

  static Future<void> clear() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }

  static List<QuoteEntry> _trim(List<QuoteEntry> entries) {
    if (entries.length <= _maxQuotes) return entries;

    // Keep the most recent quotes.
    final sorted = [...entries]..sort((a, b) => b.createdAtEpochMs.compareTo(a.createdAtEpochMs));
    final kept = sorted.take(_maxQuotes).toList(growable: false);

    // Display oldest -> newest.
    kept.sort((a, b) => a.createdAtEpochMs.compareTo(b.createdAtEpochMs));
    return kept;
  }
}

class QuoteEntry {
  final String id;
  final String quote;
  final String author;
  final String? source;
  final int createdAtEpochMs;

  const QuoteEntry({
    required this.id,
    required this.quote,
    required this.author,
    required this.source,
    required this.createdAtEpochMs,
  });

  QuoteEntry copyWith({
    String? id,
    String? quote,
    String? author,
    String? source,
    int? createdAtEpochMs,
  }) {
    return QuoteEntry(
      id: id ?? this.id,
      quote: quote ?? this.quote,
      author: author ?? this.author,
      source: source ?? this.source,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'quote': quote,
        'author': author,
        'source': source,
        'createdAtEpochMs': createdAtEpochMs,
      };

  static QuoteEntry fromJson(Map<String, dynamic> m) {
    return QuoteEntry(
      id: (m['id'] ?? '').toString(),
      quote: (m['quote'] ?? '').toString(),
      author: (m['author'] ?? '').toString(),
      source: (m['source'] == null) ? null : m['source'].toString(),
      createdAtEpochMs: (m['createdAtEpochMs'] is int) ? m['createdAtEpochMs'] as int : int.tryParse('${m['createdAtEpochMs']}') ?? 0,
    );
  }
}
