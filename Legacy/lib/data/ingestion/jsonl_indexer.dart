import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';

import '../db/app_db.dart';
import '../../providers/db_provider.dart';

class JsonlIndexerDiag {
  final int readLines;
  final int inserted;
  final int skippedDupes;
  final int errors;
  final String? note;

  const JsonlIndexerDiag({
    required this.readLines,
    required this.inserted,
    required this.skippedDupes,
    required this.errors,
    this.note,
  });

  @override
  String toString() =>
      'read=$readLines inserted=$inserted dupes=$skippedDupes errors=$errors ${note ?? ''}';
}

class JsonlIndexer {
  static const _uuid = Uuid();

  String? lastDiag;
  DateTime? lastIngestUtc;

  Future<File> _rawFile() async {
    final dir = await getApplicationDocumentsDirectory();
    // NotificationListener writes here (confirmed via logs)
    return File(p.join(dir.path, 'raw_notifications.jsonl'));
  }

  Future<File> _metaFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'indexer_meta.json'));
  }

  Future<Map<String, dynamic>> _readMeta() async {
    final f = await _metaFile();
    if (!await f.exists()) return {'offset': 0};
    try {
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {'offset': 0};
    }
  }

  Future<void> _writeMeta(Map<String, dynamic> meta) async {
    final f = await _metaFile();
    await f.writeAsString(jsonEncode(meta), flush: true);
  }

  Future<void> resetMeta() async {
    await _writeMeta({'offset': 0});
  }

  static int _dayKeyUtc(DateTime dtUtc) {
    final d = DateTime.utc(dtUtc.year, dtUtc.month, dtUtc.day);
    return d.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    // Best-effort normalization across earlier versions.
    final pkg = (raw['pkg'] ?? raw['package'] ?? raw['sourcePackage'] ?? '').toString();
    final title = (raw['title'] ?? raw['notificationTitle'] ?? raw['notification_title'])?.toString();
    final body = (raw['bestBody'] ?? raw['body'] ?? raw['text'] ?? raw['notificationBody'])?.toString();

    // time fields (millis or iso); fallback now
    DateTime received = DateTime.now().toUtc();
    final ts = raw['postedAt'] ?? raw['timestamp'] ?? raw['when'] ?? raw['time'] ?? raw['receivedAt'];
    if (ts is int) {
      try { received = DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true); } catch (_) {}
    } else if (ts is String) {
      try { received = DateTime.parse(ts).toUtc(); } catch (_) {}
    }

    return {
      'id': raw['id']?.toString() ?? _uuid.v4(),
      'receivedAt': received.toIso8601String(),
      'sourcePackage': pkg.isEmpty ? 'unknown' : pkg,
      'title': title,
      'body': body,
      'rawJson': jsonEncode(raw),
      'dayKey': _dayKeyUtc(received),
    };
  }

  Future<int> runOnce({bool dedupe24h = true, int maxLines = 800}) async {
    final db = DbProvider.db;
    final rawFile = await _rawFile();
    if (!await rawFile.exists()) {
      lastDiag = const JsonlIndexerDiag(readLines: 0, inserted: 0, skippedDupes: 0, errors: 0, note: 'raw file missing').toString();
      return 0;
    }

    final meta = await _readMeta();
    int offset = (meta['offset'] as int?) ?? 0;

    int readLines = 0;
    int inserted = 0;
    int skippedDupes = 0;
    int errors = 0;

    final raf = await rawFile.open(mode: FileMode.read);
    try {
      final length = await raf.length();
      if (offset > length) offset = 0;

      await raf.setPosition(offset);
      final bytes = await raf.read(length - offset);
      final chunk = utf8.decode(bytes, allowMalformed: true);
      final lines = chunk.split('\n');

      for (final line in lines) {
        if (readLines >= maxLines) break;
        final l = line.trim();
        if (l.isEmpty) continue;
        readLines++;

        Map<String, dynamic> raw;
        try {
          raw = jsonDecode(l) as Map<String, dynamic>;
        } catch (_) {
          errors++;
          continue;
        }

        final norm = _normalize(raw);

        final id = norm['id'] as String;
        final receivedAt = DateTime.parse(norm['receivedAt'] as String).toUtc();
        final pkg = norm['sourcePackage'] as String;
        final title = norm['title'] as String?;
        final body = norm['body'] as String?;
        final rawJson = norm['rawJson'] as String;
        final dayKey = norm['dayKey'] as int;

        if (dedupe24h) {
          try {
            final dupe = await db.hasDuplicateInLast24h(
        receivedAt: receivedAt,
              sourcePackage: pkg,
              title: title,
              body: body,
            );
            if (dupe) { skippedDupes++; continue; }
          } catch (_) {}
        }

        try {
          await db.upsertSignal(
            id: id,
            receivedAt: receivedAt,
            sourcePackage: pkg,
            title: title,
            body: body,
            rawJson: rawJson,
            dayKey: dayKey,
          );
          inserted++;
        } catch (_) {
          errors++;
        }
      }

      // advance offset fully (simple, deterministic)
      final newOffset = length;
      await _writeMeta({'offset': newOffset});
      lastIngestUtc = DateTime.now().toUtc();
      lastDiag = JsonlIndexerDiag(readLines: readLines, inserted: inserted, skippedDupes: skippedDupes, errors: errors).toString();
      
      // Bridge metric: dedupe saves time. Conservative estimate per duplicate.
      if (skippedDupes > 0) {
        const secondsPerDupe = 10; // v1 heuristic; can be tuned later
        final secondsSaved = skippedDupes * secondsPerDupe;
        await DbProvider.db.into(DbProvider.db.timeSavingsTable).insert(
              TimeSavingsTableCompanion(
                id: Value(const Uuid().v4()),
                category: const Value('dedupe'),
                secondsSaved: Value(secondsSaved),
                confidence: const Value(0.35),
                traceId: const Value(null),
                createdAt: Value(DateTime.now().toUtc()),
              ),
            );
      }
return inserted;
    } finally {
      await raf.close();
    }
  }
}

