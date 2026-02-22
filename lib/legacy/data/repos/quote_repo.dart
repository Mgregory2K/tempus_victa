import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/quote_model.dart';

class QuoteRepo {
  static const _fileName = 'quotes.jsonl';
  final _uuid = const Uuid();

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<List<QuoteItem>> list({bool includeArchived = false}) async {
    final f = await _file();
    if (!await f.exists()) return const [];

    final lines = await f.readAsLines();
    final items = <QuoteItem>[];

    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final item = QuoteItem.tryFromJsonLine(t);
      if (item == null) continue;
      if (!includeArchived && item.archived) continue;
      items.add(item);
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<QuoteItem> addManual({required String text, String? author}) async {
    final item = QuoteItem(
      id: _uuid.v4(),
      createdAt: DateTime.now().toUtc(),
      text: text.trim(),
      author: author?.trim(),
    );
    return _append(item);
  }

  Future<void> archive(String id) async {
    final items = await list(includeArchived: true);
    final next = items.map((q) => q.id == id ? q.copyWith(archived: true) : q).toList();
    await _rewrite(next);
  }

  Future<QuoteItem> _append(QuoteItem item) async {
    final f = await _file();
    await f.create(recursive: true);
    await f.writeAsString('${item.toJsonLine()}\n', mode: FileMode.append, flush: true);
    return item;
  }

  Future<void> _rewrite(List<QuoteItem> items) async {
    final f = await _file();
    await f.create(recursive: true);
    final buf = StringBuffer();
    for (final it in items) {
      buf.writeln(it.toJsonLine());
    }
    await f.writeAsString(buf.toString(), mode: FileMode.write, flush: true);
  }
}
