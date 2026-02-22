class Signal {
  final int id;
  final String content;
  final String source;
  final DateTime receivedAt;
  final DateTime createdAt;
  final DateTime modifiedAt;

  Signal({
    required this.id,
    required this.content,
    required this.source,
    required this.receivedAt,
    required this.createdAt,
    required this.modifiedAt,
  });
}
