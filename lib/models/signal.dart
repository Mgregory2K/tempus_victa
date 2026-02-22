class SignalModel {
  final int? id;
  final String content;
  final String source;
  final DateTime createdAt;
  final bool isRecycled;

  SignalModel({
    this.id,
    required this.content,
    required this.source,
    required this.createdAt,
    this.isRecycled = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'source': source,
      'created_at': createdAt.toIso8601String(),
      'is_recycled': isRecycled ? 1 : 0,
    };
  }

  factory SignalModel.fromMap(Map<String, dynamic> map) {
    return SignalModel(
      id: map['id'],
      content: map['content'],
      source: map['source'],
      createdAt: DateTime.parse(map['created_at']),
      isRecycled: map['is_recycled'] == 1,
    );
  }
}
