import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/quote_item_model.dart';

/// Local-first Quote store.
///
/// Storage: JSONL in app documents directory.
///
/// Notes:
/// - We keep the format compatible with future "append events" evolution.
/// - For now, deletes are implemented via rewrite.
class QuotesRepo {
  static const _fileName = 'quotes.jsonl';
  final _uuid = const Uuid();

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<List<QuoteItem>> list() async {
    final f = await _file();
    if (!await f.exists()) return const [];

    final lines = await f.readAsLines();
    final out = <QuoteItem>[];

    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;

      final item = QuoteItem.tryFromJsonLine(t);
      if (item == null) continue;
      if (item.text.trim().isEmpty) continue;

      out.add(item);
    }

    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  Future<QuoteItem> add({
    required String text,
    String? sourceCorkId,
  }) async {
    final q = QuoteItem(
      id: _uuid.v4(),
      createdAt: DateTime.now().toUtc(),
      text: text.trim(),
      sourceCorkId: sourceCorkId,
    );
    await _append(q);
    return q;
  }

  Future<void> delete(String id) async {
    await _rewrite((q) => q.id == id ? null : q);
  }

  Future<void> clearAll() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }

  Future<void> _append(QuoteItem item) async {
    final f = await _file();
    await f.parent.create(recursive: true);
    await f.writeAsString('${item.toJsonLine()}\n', mode: FileMode.append, flush: true);
  }

  Future<void> _rewrite(QuoteItem? Function(QuoteItem) map) async {
    final f = await _file();
    if (!await f.exists()) return;

    final lines = await f.readAsLines();
    final out = StringBuffer();

    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;

      final item = QuoteItem.tryFromJsonLine(t);
      if (item == null) continue;

      final next = map(item);
      if (next == null) continue;

      out.writeln(next.toJsonLine());
    }

    await f.writeAsString(out.toString(), mode: FileMode.write, flush: true);
  }
}
