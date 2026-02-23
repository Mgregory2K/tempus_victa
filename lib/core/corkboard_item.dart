import 'package:flutter/foundation.dart';

@immutable
class CorkboardItem {
  final String id;
  final String text;
  final DateTime createdAt;

  // Optional source linkage (e.g., signal fingerprint)
  final String? source;
  final String? sourceId;

  const CorkboardItem({
    required this.id,
    required this.text,
    required this.createdAt,
    this.source,
    this.sourceId,
  });

  CorkboardItem copyWith({
    String? id,
    String? text,
    DateTime? createdAt,
    String? source,
    String? sourceId,
  }) {
    return CorkboardItem(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAtMs': createdAt.millisecondsSinceEpoch,
        'source': source,
        'sourceId': sourceId,
      };

  static CorkboardItem fromJson(Map<String, dynamic> m) {
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      (m['createdAtMs'] is int) ? m['createdAtMs'] as int : int.tryParse('${m['createdAtMs']}') ?? DateTime.now().millisecondsSinceEpoch,
    );
    return CorkboardItem(
      id: (m['id'] ?? createdAt.microsecondsSinceEpoch.toString()).toString(),
      text: (m['text'] ?? '').toString(),
      createdAt: createdAt,
      source: m['source'] as String?,
      sourceId: m['sourceId'] as String?,
    );
  }
}
