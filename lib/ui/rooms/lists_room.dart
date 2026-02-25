import 'package:flutter/material.dart';

import '../../core/app_state_scope.dart';
import '../../core/list_item.dart';
import '../../core/list_store.dart';
import '../../core/twin_plus/twin_event.dart';
import '../../core/twin_plus/twin_plus_scope.dart';
import '../room_frame.dart';

class ListsRoom extends StatefulWidget {
  final String roomName;
  const ListsRoom({super.key, required this.roomName});

  @override
  State<ListsRoom> createState() => _ListsRoomState();
}

class _ListsRoomState extends State<ListsRoom> {
  List<ListItem> _lists = <ListItem>[];
  ListItem? _selected;
  final _newListCtrl = TextEditingController();
  final _addItemCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await ListStore.load();
    if (!mounted) return;
    setState(() {
      _lists = all;
      _selected = _selected == null
          ? (all.isEmpty ? null : all.first)
          : all.firstWhere((e) => e.id == _selected!.id, orElse: () => all.isEmpty ? _selected! : all.first);
    });
  }

  Future<void> _createList() async {
    final name = _newListCtrl.text.trim();
    if (name.isEmpty) return;
    await ListStore.createIfMissing(name);
    TwinPlusScope.of(context).observe(
      TwinEvent.actionPerformed(surface: 'lists', action: 'list_created', entityType: 'list', meta: {'name': name}),
    );
    _newListCtrl.clear();
    await _load();
  }

  Future<void> _addItems() async {
    final sel = _selected;
    if (sel == null) return;
    final raw = _addItemCtrl.text.trim();
    if (raw.isEmpty) return;
    final items = raw.contains(',') ? raw.split(',') : [raw];
    await ListStore.addItems(sel.name, items);
    TwinPlusScope.of(context).observe(
      TwinEvent.actionPerformed(surface: 'lists', action: 'list_items_added', entityType: 'list', entityId: sel.id, meta: {'count': items.length}),
    );
    _addItemCtrl.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return RoomFrame(
      title: widget.roomName,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newListCtrl,
                    decoration: const InputDecoration(hintText: 'Create list (e.g., Grocery)'),
                    onSubmitted: (_) => _createList(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _createList, child: const Text('Create')),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 170,
                    child: ListView(
                      children: _lists
                          .map((l) => ListTile(
                                title: Text(l.name),
                                selected: _selected?.id == l.id,
                                onTap: () => setState(() => _selected = l),
                              ))
                          .toList(growable: false),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _selected == null
                        ? const Center(child: Text('No lists yet. Create one.'))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(_selected!.name, style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _addItemCtrl,
                                      decoration: const InputDecoration(hintText: 'Add item(s) (comma separated ok)'),
                                      onSubmitted: (_) => _addItems(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(onPressed: _addItems, child: const Text('Add')),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListView(
                                  children: _selected!.entries.map((e) {
                                    return CheckboxListTile(
                                      value: e.checked,
                                      title: Text(e.text),
                                      onChanged: (_) async {
                                        await ListStore.toggle(_selected!.id, e.id);
                                        TwinPlusScope.of(context).observe(
                                          TwinEvent.actionPerformed(
                                            surface: 'lists',
                                            action: 'list_item_toggled',
                                            entityType: 'list_entry',
                                            entityId: e.id,
                                            meta: {'listId': _selected!.id},
                                          ),
                                        );
                                        await _load();
                                      },
                                    );
                                  }).toList(growable: false),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
