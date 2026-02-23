import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'cork_item.dart';

/// Local-first corkboard storage.
/// JSONL file in app documents directory to keep it dead-simple and durable.
class CorkboardRepo {
  static const _fileName = 'corkboard.jsonl';
  final _uuid = const Uuid();

  Future<File> _file() async {
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
      final it = CorkItem.tryFromJsonLine(t);
      if (it == null) continue;
      if (!includeArchived && it.archived) continue;
      items.add(it);
    }

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

  Future<CorkItem> addFromSignal({required String signalId, required String content}) async {
    return _append(
      CorkItem(
        id: _uuid.v4(),
        createdAt: DateTime.now().toUtc(),
        content: content.trim(),
        sourceSignalId: signalId,
      ),
    );
  }

  Future<void> archive(String id) async {
    await _rewrite((it) => it.id == id ? it.copyWith(archived: true) : it);
  }

  Future<void> updateContent(String id, String content) async {
    await _rewrite((it) => it.id == id ? it.copyWith(content: content.trim()) : it);
  }

  Future<void> delete(String id) async {
    await _rewrite((it) => it.id == id ? null : it);
  }

  Future<CorkItem> _append(CorkItem item) async {
    final f = await _file();
    await f.parent.create(recursive: true);
    await f.writeAsString('${item.toJsonLine()}\n', mode: FileMode.append, flush: true);
    return item;
  }

  Future<void> _rewrite(CorkItem? Function(CorkItem) map) async {
    final f = await _file();
    if (!await f.exists()) return;

    final lines = await f.readAsLines();
    final out = StringBuffer();

    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final it = CorkItem.tryFromJsonLine(t);
      if (it == null) continue;

      final mapped = map(it);
      if (mapped == null) continue;
      out.writeln(mapped.toJsonLine());
    }

    await f.writeAsString(out.toString(), mode: FileMode.write, flush: true);
  }
}
