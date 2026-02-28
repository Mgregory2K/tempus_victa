import 'dart:io';

import 'package:path_provider/path_provider.dart';

class StorageStats {
  final int audioFiles;
  final int audioBytes;

  const StorageStats({
    required this.audioFiles,
    required this.audioBytes,
  });
}

class StorageStatsService {
  static final StorageStatsService instance = StorageStatsService._internal();
  StorageStatsService._internal();

  Future<Directory> _audioDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return Directory('${dir.path}/audio');
  }

  Future<StorageStats> compute() async {
    final d = await _audioDir();
    if (!await d.exists()) {
      return const StorageStats(audioFiles: 0, audioBytes: 0);
    }
    int files = 0;
    int bytes = 0;
    try {
      await for (final ent in d.list(recursive: true, followLinks: false)) {
        if (ent is File) {
          files++;
          try {
            bytes += await ent.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return StorageStats(audioFiles: files, audioBytes: bytes);
  }

  Future<void> clearAudio() async {
    final d = await _audioDir();
    if (!await d.exists()) return;
    try {
      await for (final ent in d.list(recursive: true, followLinks: false)) {
        if (ent is File) {
          try { await ent.delete(); } catch (_) {}
        }
      }
    } catch (_) {}
  }

  static String prettyBytes(int b) {
    if (b < 1024) return '$b B';
    final kb = b / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024.0;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024.0;
    return '${gb.toStringAsFixed(2)} GB';
  }
}
