import 'package:flutter/material.dart';
import 'package:tempus_victa/services/router/router.dart';
import 'package:tempus_victa/services/router/router_service.dart';
import 'package:tempus_victa/services/ask_user/ask_user.dart';

class DraftsScreen extends StatefulWidget {
  const DraftsScreen({super.key});

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  late final LocalStore _store;
  late final AskUserManager _manager;
  List<Map<String, dynamic>> _drafts = [];

  @override
  void initState() {
    super.initState();
    _store = RouterService.instance.store!;
    _manager = AskUserManager(_store);
    _loadDrafts();
  }

  void _loadDrafts() {
    setState(() {
      _drafts = _store.items.values
          .where((i) => i['type'] == 'draft')
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    });
  }

  void _applyDraft(Map<String, dynamic> draft) {
    final provId = draft['source_ref'] as String?;
    if (provId == null) return;
    final overrides = <String, dynamic>{};
    if (draft['title'] != null) overrides['title'] = draft['title'];
    if (draft['metadata'] != null) overrides['metadata'] =
        Map<String, dynamic>.from(draft['metadata']);
    _manager.accept(provId, overrides: overrides);
    _loadDrafts();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Draft applied as commit')));
  }

  void _deleteDraft(Map<String, dynamic> draft) {
    final id = draft['item_id'] as String?;
    if (id == null) return;
    _store.deleteItem(id);
    _loadDrafts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drafts')),
      body: ListView.builder(
        itemCount: _drafts.length,
        itemBuilder: (context, i) {
          final d = _drafts[i];
          return ListTile(
            title: Text(d['title'] ?? 'draft'),
            subtitle: Text(d['metadata']?.toString() ?? ''),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                  onPressed: () => _applyDraft(d), icon: const Icon(Icons.upload)),
              IconButton(
                  onPressed: () => _deleteDraft(d), icon: const Icon(Icons.delete)),
            ]),
            onTap: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                      title: const Text('Draft'),
                      content: SingleChildScrollView(child: Text(d.toString())),
                    )),
          );
        },
      ),
    );
  }
}
