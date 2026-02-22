import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/action_item_model.dart';

class ActionsRepo {
  static const _fileName = 'actions.jsonl';
  final _uuid = const Uuid();

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<List<ActionItem>> list({
    bool includeInbox = true,
    bool includeActive = true,
    bool includeDone = true,
    bool includeArchived = false,
  }) async {
    final f = await _file();
    if (!await f.exists()) return const [];

    final lines = await f.readAsLines();
    final out = <ActionItem>[];

    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;

      final item = ActionItem.tryFromJsonLine(t);
      if (item == null) continue;

      if (!includeArchived && item.status == ActionStatus.archived) continue;
      if (!includeDone && item.status == ActionStatus.done) continue;
      if (!includeInbox && item.status == ActionStatus.inbox) continue;
      if (!includeActive && item.status == ActionStatus.active) continue;

      out.add(item);
    }

    // Sort:
    // 1) inbox first
    // 2) active
    // 3) done
    // 4) archived
    // Within inbox/active: due soonest, then newest
    int rank(ActionStatus s) {
      if (s == ActionStatus.inbox) return 0;
      if (s == ActionStatus.active) return 1;
      if (s == ActionStatus.done) return 2;
      return 3;
    }

    out.sort((a, b) {
      final r = rank(a.status).compareTo(rank(b.status));
      if (r != 0) return r;

      final ad = a.dueAt;
      final bd = b.dueAt;
      if (ad != null && bd != null) {
        final d = ad.compareTo(bd);
        if (d != 0) return d;
      } else if (ad != null && bd == null) {
        return -1;
      } else if (ad == null && bd != null) {
        return 1;
      }

      return b.createdAt.compareTo(a.createdAt);
    });

    return out;
  }

  Future<ActionItem> add({
    required String title,
    String? notes,
    DateTime? dueAt,
    String? sourceCorkId,
    String? sourceSignalId,
    String? source,
    ActionStatus status = ActionStatus.inbox,
  }) async {
    final now = DateTime.now().toUtc();
    final item = ActionItem(
      id: _uuid.v4(),
      createdAt: now,
      capturedAt: now,
      modifiedAt: now,
      title: title.trim(),
      notes: (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
      dueAt: dueAt,
      status: status,
      sourceCorkId: sourceCorkId,
      sourceSignalId: sourceSignalId,
      source: source,
    );
    await _append(item);
    return item;
  }

  Future<void> toggleDone(String id) async {
    await _rewrite((it) {
      if (it.id != id) return it;
      final next = it.status == ActionStatus.done ? ActionStatus.active : ActionStatus.done;
      return it.copyWith(status: next, modifiedAt: DateTime.now().toUtc());
    });
  }

  Future<void> activate(String id) async {
    await _rewrite((it) {
      if (it.id != id) return it;
      return it.copyWith(status: ActionStatus.active, modifiedAt: DateTime.now().toUtc());
    });
  }

  Future<void> archive(String id) async {
    await _rewrite((it) => it.id == id
        ? it.copyWith(status: ActionStatus.archived, modifiedAt: DateTime.now().toUtc())
        : it);
  }

  Future<void> update({
    required String id,
    String? title,
    String? notes,
    DateTime? dueAt,
  }) async {
    await _rewrite((it) {
      if (it.id != id) return it;
      return it.copyWith(
        title: title ?? it.title,
        notes: notes ?? it.notes,
        dueAt: dueAt ?? it.dueAt,
        modifiedAt: DateTime.now().toUtc(),
      );
    });
  }

  Future<void> clearAll() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }

  Future<void> _append(ActionItem item) async {
    final f = await _file();
    await f.parent.create(recursive: true);
    await f.writeAsString('${item.toJsonLine()}\n', mode: FileMode.append, flush: true);
  }

  Future<void> _rewrite(ActionItem Function(ActionItem) map) async {
    final f = await _file();
    if (!await f.exists()) return;

    final lines = await f.readAsLines();
    final out = StringBuffer();

    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;

      final item = ActionItem.tryFromJsonLine(t);
      if (item == null) continue;

      out.writeln(map(item).toJsonLine());
    }

    await f.writeAsString(out.toString(), mode: FileMode.write, flush: true);
  }
}