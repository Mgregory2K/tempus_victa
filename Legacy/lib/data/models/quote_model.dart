import 'dart:convert';

class QuoteItem {
  final String id;
  final DateTime createdAt;
  final String text;
  final String? author;
  final bool archived;

  const QuoteItem({
    required this.id,
    required this.createdAt,
    required this.text,
    this.author,
    this.archived = false,
  });

  QuoteItem copyWith({
    String? id,
    DateTime? createdAt,
    String? text,
    String? author,
    bool? archived,
  }) {
    return QuoteItem(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      text: text ?? this.text,
      author: author ?? this.author,
      archived: archived ?? this.archived,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'text': text,
        'author': author,
        'archived': archived,
      };

  static QuoteItem? tryFromJsonLine(String line) {
    try {
      final j = jsonDecode(line) as Map<String, dynamic>;
      return QuoteItem(
        id: (j['id'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toUtc() ?? DateTime.now().toUtc(),
        text: (j['text'] ?? '').toString(),
        author: j['author']?.toString(),
        archived: (j['archived'] ?? false) == true,
      );
    } catch (_) {
      return null;
    }
  }

  String toJsonLine() => jsonEncode(toJson());
}
