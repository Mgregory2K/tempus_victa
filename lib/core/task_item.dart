import 'package:flutter/foundation.dart';

@immutable
class TaskItem {
  final String id;
  final String title;

  final String? audioPath;
  final int? audioDurationMs;

  final String? transcript;

  final String? decisionId;

  final DateTime createdAt;
  final bool isCompleted;

  final String? projectId;

  const TaskItem({
    required this.id,
    required this.title,
    required this.createdAt,
    this.audioPath,
    this.audioDurationMs,
    this.transcript,
    this.decisionId,
    this.isCompleted = false,
    this.projectId,
  });

  TaskItem copyWith({
    String? id,
    String? title,
    String? audioPath,
    int? audioDurationMs,
    String? transcript,
    String? decisionId,
    DateTime? createdAt,
    bool? isCompleted,
    String? projectId,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      audioPath: audioPath ?? this.audioPath,
      audioDurationMs: audioDurationMs ?? this.audioDurationMs,
      transcript: transcript ?? this.transcript,
      decisionId: decisionId ?? this.decisionId,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
      projectId: projectId ?? this.projectId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'audioPath': audioPath,
        'audioDurationMs': audioDurationMs,
        'transcript': transcript,
        'decisionId': decisionId,
        'createdAtMs': createdAt.millisecondsSinceEpoch,
        'isCompleted': isCompleted,
        'projectId': projectId,
      };

  static TaskItem fromJson(Map<String, dynamic> m) {
    return TaskItem(
      id: (m['id'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      audioPath: m['audioPath'] as String?,
      audioDurationMs: m['audioDurationMs'] is int ? m['audioDurationMs'] as int : int.tryParse('${m['audioDurationMs']}'),
      transcript: m['transcript'] as String?,
      decisionId: m['decisionId'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (m['createdAtMs'] is int) ? m['createdAtMs'] as int : int.tryParse('${m['createdAtMs']}') ?? DateTime.now().millisecondsSinceEpoch,
      ),
      isCompleted: (m['isCompleted'] is bool) ? (m['isCompleted'] as bool) : ('${m['isCompleted']}' == 'true'),
      projectId: m['projectId'] as String?,
    );
  }

  static String titleFromTranscript(String? transcript, {int maxWords = 6}) {
    final t = (transcript ?? '').trim();
    if (t.isEmpty) return 'Voice capture';
    final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'Voice capture';
    return words.take(maxWords).join(' ');
  }
}
