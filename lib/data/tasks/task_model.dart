class TaskModel {
  final String id;
  final int createdAtEpochMs;

  // Display
  final String title; // short title shown in list (can be derived from transcript later)
  final String? transcript; // full transcript (optional; may be large)
  final String? transcriptPreview; // short preview (keeps list clean)

  // Attachments
  final String? audioPath; // local file path (m4a)

  // Metadata
  final String source; // e.g. "bridge_mic", "manual_text", "signal_promoted"
  final bool isCompleted;

  const TaskModel({
    required this.id,
    required this.createdAtEpochMs,
    required this.title,
    required this.source,
    this.transcript,
    this.transcriptPreview,
    this.audioPath,
    this.isCompleted = false,
  });

  TaskModel copyWith({
    String? title,
    String? transcript,
    String? transcriptPreview,
    String? audioPath,
    bool? isCompleted,
  }) {
    return TaskModel(
      id: id,
      createdAtEpochMs: createdAtEpochMs,
      title: title ?? this.title,
      transcript: transcript ?? this.transcript,
      transcriptPreview: transcriptPreview ?? this.transcriptPreview,
      audioPath: audioPath ?? this.audioPath,
      source: source,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAtEpochMs': createdAtEpochMs,
        'title': title,
        'transcript': transcript,
        'transcriptPreview': transcriptPreview,
        'audioPath': audioPath,
        'source': source,
        'isCompleted': isCompleted,
      };

  static TaskModel fromJson(Map<String, dynamic> j) => TaskModel(
        id: j['id'] as String,
        createdAtEpochMs: j['createdAtEpochMs'] as int,
        title: j['title'] as String,
        transcript: j['transcript'] as String?,
        transcriptPreview: j['transcriptPreview'] as String?,
        audioPath: j['audioPath'] as String?,
        source: (j['source'] as String?) ?? 'unknown',
        isCompleted: (j['isCompleted'] as bool?) ?? false,
      );
}
