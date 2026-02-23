class SignalItem {
  final String id;
  final DateTime createdAt;
  final String source; // e.g., package name
  final String title;
  final String? body;

  /// Dedupe + insight
  final String fingerprint; // pkg|title|body
  final DateTime lastSeenAt;
  final int count;

  /// User state
  final bool acknowledged;

  const SignalItem({
    required this.id,
    required this.createdAt,
    required this.source,
    required this.title,
    this.body,
    required this.fingerprint,
    required this.lastSeenAt,
    this.count = 1,
    this.acknowledged = false,
  });

  SignalItem copyWith({
    String? id,
    DateTime? createdAt,
    String? source,
    String? title,
    String? body,
    String? fingerprint,
    DateTime? lastSeenAt,
    int? count,
    bool? acknowledged,
  }) {
    return SignalItem(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
      title: title ?? this.title,
      body: body ?? this.body,
      fingerprint: fingerprint ?? this.fingerprint,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      count: count ?? this.count,
      acknowledged: acknowledged ?? this.acknowledged,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'source': source,
        'title': title,
        'body': body,
        'fingerprint': fingerprint,
        'lastSeenAt': lastSeenAt.toIso8601String(),
        'count': count,
        'acknowledged': acknowledged,
      };

  static SignalItem fromJson(Map<String, dynamic> j) {
    final createdAt = DateTime.tryParse('${j['createdAt'] ?? ''}') ?? DateTime.now();
    final source = (j['source'] as String?) ?? 'unknown';
    final title = (j['title'] as String?) ?? 'Signal';
    final body = j['body'] as String?;
    final fp = (j['fingerprint'] as String?) ??
        '${source}|${title}|${body ?? ''}';
    final lastSeen = DateTime.tryParse('${j['lastSeenAt'] ?? ''}') ?? createdAt;
    final count = (j['count'] is int) ? j['count'] as int : int.tryParse('${j['count']}') ?? 1;
    final ack = (j['acknowledged'] is bool) ? j['acknowledged'] as bool : ('${j['acknowledged']}' == 'true');

    return SignalItem(
      id: (j['id'] as String?) ?? createdAt.microsecondsSinceEpoch.toString(),
      createdAt: createdAt,
      source: source,
      title: title,
      body: body,
      fingerprint: fp,
      lastSeenAt: lastSeen,
      count: count < 1 ? 1 : count,
      acknowledged: ack,
    );
  }
}
