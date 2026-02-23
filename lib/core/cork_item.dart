class CorkItem {
  final String id;
  final DateTime createdAt;
  final String text;

  const CorkItem({
    required this.id,
    required this.createdAt,
    required this.text,
  });

  CorkItem copyWith({String? id, DateTime? createdAt, String? text}) {
    return CorkItem(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      text: text ?? this.text,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'text': text,
      };

  static CorkItem fromJson(Map<String, dynamic> j) {
    final createdAt = DateTime.tryParse('${j['createdAt'] ?? ''}') ?? DateTime.now();
    final id = (j['id'] as String?) ?? createdAt.microsecondsSinceEpoch.toString();
    final text = (j['text'] as String?) ?? '';
    return CorkItem(id: id, createdAt: createdAt, text: text);
  }
}
