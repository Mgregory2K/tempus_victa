import 'dart:convert';

class CorkItem {
  final String id;
  final DateTime createdAt;
  final String content;
  final String? sourceSignalId;
  final bool archived;

  const CorkItem({
    required this.id,
    required this.createdAt,
    required this.content,
    this.sourceSignalId,
    this.archived = false,
  });

  CorkItem copyWith({
    String? id,
    DateTime? createdAt,
    String? content,
    String? sourceSignalId,
    bool? archived,
  }) {
    return CorkItem(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      content: content ?? this.content,
      sourceSignalId: sourceSignalId ?? this.sourceSignalId,
      archived: archived ?? this.archived,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'content': content,
        'sourceSignalId': sourceSignalId,
        'archived': archived,
      };

  String toJsonLine() => jsonEncode(toJson());

  static CorkItem? tryFromJsonLine(String line) {
    try {
      final j = jsonDecode(line) as Map<String, dynamic>;
      final createdAt = DateTime.tryParse('${j['createdAt'] ?? ''}') ?? DateTime.now().toUtc();
      return CorkItem(
        id: (j['id'] as String?) ?? createdAt.microsecondsSinceEpoch.toString(),
        createdAt: createdAt,
        content: (j['content'] as String?) ?? '',
        sourceSignalId: j['sourceSignalId'] as String?,
        archived: (j['archived'] is bool) ? j['archived'] as bool : ('${j['archived']}' == 'true'),
      );
    } catch (_) {
      return null;
    }
  }
}
