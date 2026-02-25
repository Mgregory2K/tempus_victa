import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'list_item.dart';
import 'unified_index_service.dart';

class ListStore {
  static const String _kKey = 'tempus.lists.v1';

  static Future<List<ListItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return <ListItem>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <ListItem>[];
    return decoded
        .whereType<Map>()
        .map((e) => ListItem.fromJson(e.cast<String, dynamic>()))
        .toList(growable: true);
  }

  static Future<void> save(List<ListItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  static String _norm(String s) => s.trim().toLowerCase();

  static Future<ListItem?> getByName(String name) async {
    final n = _norm(name);
    final items = await load();
    for (final l in items) {
      if (_norm(l.name) == n) return l;
    }
    return null;
  }

  static Future<ListItem> createIfMissing(String name) async {
    final existing = await getByName(name);
    if (existing != null) return existing;

    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    final list = ListItem(id: id, createdAt: now, name: name.trim(), entries: const []);
    final all = await load();
    all.insert(0, list);
    await save(all);
    await _index(list);
    return list;
  }

  static Future<ListItem> addItems(String listName, List<String> items) async {
    final list = await createIfMissing(listName);
    final now = DateTime.now();

    final existingTexts = list.entries.map((e) => _norm(e.text)).toSet();
    final newEntries = <ListEntry>[];
    for (final it in items.map((e) => e.trim()).where((e) => e.isNotEmpty)) {
      if (existingTexts.contains(_norm(it))) continue;
      newEntries.add(ListEntry(
        id: (now.microsecondsSinceEpoch + newEntries.length).toString(),
        createdAt: now,
        text: it,
        checked: false,
      ));
    }
    if (newEntries.isEmpty) return list;

    final updated = list.copyWith(entries: [...newEntries, ...list.entries]);
    await _replace(updated);
    return updated;
  }

  static Future<ListItem> removeItems(String listName, List<String> items) async {
    final list = await createIfMissing(listName);
    final removeSet = items.map(_norm).toSet();
    final updated = list.copyWith(entries: list.entries.where((e) => !removeSet.contains(_norm(e.text))).toList(growable: false));
    await _replace(updated);
    return updated;
  }

  static Future<ListItem> clear(String listName) async {
    final list = await createIfMissing(listName);
    final updated = list.copyWith(entries: const []);
    await _replace(updated);
    return updated;
  }

  static Future<ListItem> toggle(String listId, String entryId) async {
    final all = await load();
    final idx = all.indexWhere((e) => e.id == listId);
    if (idx < 0) throw StateError('List not found');
    final list = all[idx];
    final entries = list.entries.map((e) {
      if (e.id != entryId) return e;
      return e.copyWith(checked: !e.checked);
    }).toList(growable: false);
    final updated = list.copyWith(entries: entries);
    all[idx] = updated;
    await save(all);
    await _index(updated);
    return updated;
  }

  static Future<void> _replace(ListItem updated) async {
    final all = await load();
    all.removeWhere((e) => e.id == updated.id);
    all.insert(0, updated);
    await save(all);
    await _index(updated);
  }

  static Future<void> _index(ListItem list) async {
    final unchecked = list.entries.where((e) => !e.checked).map((e) => e.text).take(25).join(', ');
    await UnifiedIndexService.upsert(
      id: list.id,
      type: 'list',
      title: list.name,
      body: unchecked,
      meta: {'entries': list.entries.length},
    );
  }
}
