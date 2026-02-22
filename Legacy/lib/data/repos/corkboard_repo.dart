import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/corkboard_model.dart';

class CorkboardRepo {
  static const _fileName = 'corkboard.jsonl';
  final _uuid = const Uuid();

  Future<File> _file() async {
    // Keep it simple + stable across platforms:
    // /data/user/0/<pkg>/app_flutter/ on Android (docs dir)
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<List<CorkItem>> list({bool includeArchived = false}) async {
    final f = await _file();
    if (!await f.exists()) return const [];

    final lines = await f.readAsLines();
    final items = <CorkItem>[];

    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final item = CorkItem.tryFromJsonLine(t);
      if (item == null) continue;
      if (!includeArchived && item.archived) continue;
      items.add(item);
    }

    // newest first
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<CorkItem> addManual(String content) async {
    return _append(
      CorkItem(
        id: _uuid.v4(),
        createdAt: DateTime.now().toUtc(),
        content: content.trim(),
      ),
    );
  }

  Future<CorkItem> addFromSignal({
    required String signalId,
    required String content,
  }) async {
    return _append(
      CorkItem(
        id: _uuid.v4(),
        createdAt: DateTime.now().toUtc(),
        content: content.trim(),
        sourceSignalId: signalId,
      ),
    );
  }

  Future<CorkItem> _append(CorkItem item) async {
    final f = await _file();
    await f.parent.create(recursive: true);

    // append JSONL
    await f.writeAsString('${item.toJsonLine()}\n', mode: FileMode.append, flush: true);
    return item;
  }

  Future<void> archive(String id) async {
    await _rewrite((item) => item.id == id ? item.copyWith(archived: true) : item);
  }

  Future<void> unarchive(String id) async {
    await _rewrite((item) => item.id == id ? item.copyWith(archived: false) : item);
  }

  Future<void> updateContent(String id, String content) async {
    await _rewrite((item) => item.id == id ? item.copyWith(content: content.trim()) : item);
  }

  Future<void> clearAll() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }

  Future<void> _rewrite(CorkItem Function(CorkItem) map) async {
    final f = await _file();
    if (!await f.exists()) return;

    final lines = await f.readAsLines();
    final out = StringBuffer();

    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;

      final item = CorkItem.tryFromJsonLine(t);
      if (item == null) continue;

      final mapped = map(item);
      out.writeln(mapped.toJsonLine());
    }

    await f.writeAsString(out.toString(), mode: FileMode.write, flush: true);
  }
}