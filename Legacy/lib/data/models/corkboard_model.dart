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
        'createdAt': createdAt.toUtc().toIso8601String(),
        'content': content,
        'sourceSignalId': sourceSignalId,
        'archived': archived,
      };

  static CorkItem fromJson(Map<String, dynamic> j) {
    return CorkItem(
      id: (j['id'] ?? '').toString(),
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toUtc() ??
          DateTime.now().toUtc(),
      content: (j['content'] ?? '').toString(),
      sourceSignalId: j['sourceSignalId']?.toString(),
      archived: (j['archived'] ?? false) == true,
    );
  }

  String toJsonLine() => jsonEncode(toJson());

  static CorkItem? tryFromJsonLine(String line) {
    try {
      final d = jsonDecode(line);
      if (d is Map<String, dynamic>) return fromJson(d);
    } catch (_) {}
    return null;
  }
}