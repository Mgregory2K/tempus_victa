import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'jsonl_store.dart';

// This file exports logs to a place you can grab them easily.
// Goal: write to Downloads if possible.
// If Android blocks it, we fall back to app external storage.
class LocalExport {
  final JsonlStore _store = JsonlStore();

  Future<Directory> _downloadsDirBestEffort() async {
    final candidates = <String>[
      '/storage/emulated/0/Download',
      '/sdcard/Download',
    ];

    for (final p in candidates) {
      final d = Directory(p);
      try {
        if (await d.exists()) {
          final test = File('${d.path}/.tempus_write_test');
          await test.writeAsString('ok', flush: true);
          await test.delete();
          return d;
        }
      } catch (_) {}
    }

    final ext = await getExternalStorageDirectory();
    if (ext != null) return ext;

    return await getApplicationDocumentsDirectory();
  }

  Future<String> exportNow() async {
    final base = await _downloadsDirBestEffort();

    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('-', '')
        .replaceAll('.', '');

    final outDir = Directory('${base.path}/TempusVicta/export_$ts');
    await outDir.create(recursive: true);

    final names = <String>[
      'raw_notifications.jsonl',
      'corkboard.jsonl',
      'unsent_events.jsonl',
    ];

    int copied = 0;

    for (final name in names) {
      final src = await _store.getFile(name);
      if (!await src.exists()) continue;

      final dest = File('${outDir.path}/$name');
      await src.copy(dest.path);
      copied++;
    }

    final readme = File('${outDir.path}/README.txt');
    await readme.writeAsString(
      'Tempus Victa local export\n'
      'Created: ${DateTime.now().toLocal().toIso8601String()}\n'
      'Export dir: ${outDir.path}\n'
      'Files copied: $copied\n',
      flush: true,
    );

    return outDir.path;
  }
}
