class TaskItem {
  final String id;
  final DateTime createdAt;

  /// Human-friendly label shown in lists.
  /// If [transcript] exists, title should be the first ~6 words.
  final String title;

  /// Optional voice capture audio file path.
  final String? audioPath;

  /// Optional audio duration in milliseconds (for quick list differentiation).
  final int? audioDurationMs;

  /// Optional full transcript (may be large). Not shown in list by default.
  final String? transcript;

  const TaskItem({
    required this.id,
    required this.createdAt,
    required this.title,
    this.audioPath,
    this.audioDurationMs,
    this.transcript,
  });

  TaskItem copyWith({
    String? title,
    String? audioPath,
    int? audioDurationMs,
    String? transcript,
  }) {
    return TaskItem(
      id: id,
      createdAt: createdAt,
      title: title ?? this.title,
      audioPath: audioPath ?? this.audioPath,
      audioDurationMs: audioDurationMs ?? this.audioDurationMs,
      transcript: transcript ?? this.transcript,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'title': title,
        'audioPath': audioPath,
        'audioDurationMs': audioDurationMs,
        'transcript': transcript,
      };

  static TaskItem fromJson(Map<String, dynamic> j) => TaskItem(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        title: j['title'] as String,
        audioPath: j['audioPath'] as String?,
        audioDurationMs: (j['audioDurationMs'] as num?)?.toInt(),
        transcript: j['transcript'] as String?,
      );

  static String titleFromTranscript(String transcript, {int maxWords = 6}) {
    final cleaned = transcript.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return 'Voice task';

    final words = cleaned.split(' ');
    final take = words.length < maxWords ? words.length : maxWords;
    return words.take(take).join(' ');
  }
}
