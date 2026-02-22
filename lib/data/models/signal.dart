// Tempus Victa - Signal model
// Everything is a Signal first.

class Signal {
  final String id;
  final String kind; // text|voice|notification|calendar|email|...
  final String? text;
  final String? transcript;
  final String source; // bridge_voice, bridge_text, ready_room, etc.
  final String status; // inbox|task|corkboard|project|recycle|archived
  final double confidence; // 0..1 (auto-routing confidence)
  final double weight; // learned importance weight
  final DateTime capturedAtUtc;
  final DateTime createdAtUtc;
  final DateTime modifiedAtUtc;

  const Signal({
    required this.id,
    required this.kind,
    required this.source,
    required this.status,
    required this.confidence,
    required this.weight,
    required this.capturedAtUtc,
    required this.createdAtUtc,
    required this.modifiedAtUtc,
    this.text,
    this.transcript,
  });

  Signal copyWith({
    String? status,
    double? confidence,
    double? weight,
    String? text,
    String? transcript,
    DateTime? modifiedAtUtc,
  }) {
    return Signal(
      id: id,
      kind: kind,
      source: source,
      status: status ?? this.status,
      confidence: confidence ?? this.confidence,
      weight: weight ?? this.weight,
      capturedAtUtc: capturedAtUtc,
      createdAtUtc: createdAtUtc,
      modifiedAtUtc: modifiedAtUtc ?? this.modifiedAtUtc,
      text: text ?? this.text,
      transcript: transcript ?? this.transcript,
    );
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'kind': kind,
        'text': text,
        'transcript': transcript,
        'source': source,
        'status': status,
        'confidence': confidence,
        'weight': weight,
        'captured_at_utc': capturedAtUtc.millisecondsSinceEpoch,
        'created_at_utc': createdAtUtc.millisecondsSinceEpoch,
        'modified_at_utc': modifiedAtUtc.millisecondsSinceEpoch,
      };

  static Signal fromRow(Map<String, Object?> r) {
    DateTime dt(Object? v) => DateTime.fromMillisecondsSinceEpoch((v as int?) ?? 0, isUtc: true);
    double d(Object? v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
    return Signal(
      id: (r['id'] as String?) ?? '',
      kind: (r['kind'] as String?) ?? 'text',
      text: r['text'] as String?,
      transcript: r['transcript'] as String?,
      source: (r['source'] as String?) ?? 'unknown',
      status: (r['status'] as String?) ?? 'inbox',
      confidence: d(r['confidence']),
      weight: d(r['weight']),
      capturedAtUtc: dt(r['captured_at_utc']),
      createdAtUtc: dt(r['created_at_utc']),
      modifiedAtUtc: dt(r['modified_at_utc']),
    );
  }
}
