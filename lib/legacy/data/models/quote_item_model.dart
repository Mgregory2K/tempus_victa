import 'dart:convert';

/// Quote item stored as JSONL.
///
/// Design goals (per Textbook/Conception):
/// - Local-first
/// - Append-only friendly (but we currently rewrite on delete)
/// - Timestamped
/// - Provenance-friendly (sourceCorkId, sourceSignalId, etc.)
class QuoteItem {
  final String id;
  final DateTime createdAt;
  final String text;

  // provenance
  final String? sourceCorkId;

  const QuoteItem({
    required this.id,
    required this.createdAt,
    required this.text,
    this.sourceCorkId,
  });

  QuoteItem copyWith({
    String? id,
    DateTime? createdAt,
    String? text,
    String? sourceCorkId,
  }) {
    return QuoteItem(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      text: text ?? this.text,
      sourceCorkId: sourceCorkId ?? this.sourceCorkId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'text': text,
        'sourceCorkId': sourceCorkId,
      };

  static QuoteItem fromJson(Map<String, dynamic> j) {
    return QuoteItem(
      id: (j['id'] ?? '').toString(),
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toUtc() ??
          DateTime.now().toUtc(),
      text: (j['text'] ?? '').toString(),
      sourceCorkId: j['sourceCorkId']?.toString(),
    );
  }

  String toJsonLine() => jsonEncode(toJson());

  static QuoteItem? tryFromJsonLine(String line) {
    try {
      final d = jsonDecode(line);
      if (d is Map<String, dynamic>) return fromJson(d);
      if (d is Map) return fromJson(d.cast<String, dynamic>());
    } catch (_) {}
    return null;
  }
}
