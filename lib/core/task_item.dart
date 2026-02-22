import 'package:flutter/foundation.dart';

@immutable
class TaskItem {
  final String id;
  final String title;

  // Voice attachments (optional)
  final String? audioPath;
  final int? audioDurationMs;

  // Transcription (optional)
  final String? transcript;

  // Metadata
  final DateTime createdAt;
  final bool isCompleted;

  // Optional routing
  final String? projectId;

  const TaskItem({
    required this.id,
    required this.title,
    required this.createdAt,
    this.audioPath,
    this.audioDurationMs,
    this.transcript,
    this.isCompleted = false,
    this.projectId,
  });

  TaskItem copyWith({
    String? id,
    String? title,
    String? audioPath,
    int? audioDurationMs,
    String? transcript,
    DateTime? createdAt,
    bool? isCompleted,
    String? projectId,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      audioPath: audioPath ?? this.audioPath,
      audioDurationMs: audioDurationMs ?? this.audioDurationMs,
      transcript: transcript ?? this.transcript,
      isCompleted: isCompleted ?? this.isCompleted,
      projectId: projectId ?? this.projectId,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'audioPath': audioPath,
        'audioDurationMs': audioDurationMs,
        'transcript': transcript,
        'createdAt': createdAt.toIso8601String(),
        'isCompleted': isCompleted,
        'projectId': projectId,
      };

  static TaskItem fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is String) {
        final dt = DateTime.tryParse(v);
        if (dt != null) return dt;
      }
      // Fallback: now (shouldn't happen, but keeps app resilient)
      return DateTime.now();
    }

    int? parseInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    return TaskItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      createdAt: parseDate(json['createdAt']),
      audioPath: json['audioPath'] as String?,
      audioDurationMs: parseInt(json['audioDurationMs']),
      transcript: json['transcript'] as String?,
      isCompleted: (json['isCompleted'] is bool)
          ? (json['isCompleted'] as bool)
          : ((json['isCompleted'] ?? false).toString() == 'true'),
      projectId: json['projectId'] as String?,
    );
  }

  /// Creates a compact title from the first N words of a transcript.
  /// Safe for null/empty input (returns "Voice capture").
  static String titleFromTranscript(String? transcript, {int maxWords = 6}) {
    final t = (transcript ?? '').trim();
    if (t.isEmpty) return 'Voice capture';

    final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'Voice capture';

    return words.take(maxWords).join(' ');
  }

  /// Helper for a consistent default voice title without transcript.
  static String defaultVoiceTitle(DateTime when, {String prefix = 'Voice'}) {
    final mm = when.month.toString().padLeft(2, '0');
    final dd = when.day.toString().padLeft(2, '0');
    final hh = when.hour.toString().padLeft(2, '0');
    final mi = when.minute.toString().padLeft(2, '0');
    return '$prefix – $mm/$dd $hh:$mi';
  }
}
