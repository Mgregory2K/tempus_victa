class SignalItem {
  final String id;
  final DateTime createdAt;
  final String source; // e.g., "notification", "sms", "call", "demo"
  final String title;
  final String? body;

  const SignalItem({
    required this.id,
    required this.createdAt,
    required this.source,
    required this.title,
    this.body,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'source': source,
        'title': title,
        'body': body,
      };

  static SignalItem fromJson(Map<String, dynamic> j) => SignalItem(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        source: (j['source'] as String?) ?? 'unknown',
        title: (j['title'] as String?) ?? 'Signal',
        body: j['body'] as String?,
      );
}
