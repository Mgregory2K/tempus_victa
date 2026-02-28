import 'package:flutter/material.dart';
import 'package:tempus_victa/services/ask_user/ask_user.dart';

class _EditResult {
  final String title;
  final String? body;
  _EditResult(this.title, this.body);
}

class AskUserScreen extends StatefulWidget {
  final AskUserManager manager;
  const AskUserScreen({Key? key, required this.manager}) : super(key: key);

  @override
  _AskUserScreenState createState() => _AskUserScreenState();
}

class _AskUserScreenState extends State<AskUserScreen> {
  late List<Map<String, dynamic>> _pending;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _pending = widget.manager.listPending();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pending Decisions')),
      body: ListView.builder(
        itemCount: _pending.length,
        itemBuilder: (context, i) {
          final p = _pending[i];
          final provId = p['prov_id'] ?? '';
          final title =
              (p['entities'] != null && p['entities']['title'] != null)
                  ? p['entities']['title']
                  : p['candidate']?['plan_id'] ?? 'action';
          return ListTile(
            title: Text(title),
            subtitle: Text('Reason: ${p['candidate']?['plan_id'] ?? ''}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              TextButton(
                onPressed: () async {
                  // Inline edit dialog before accept
                  final entities = p['entities'] as Map<String, dynamic>? ?? {};
                  final suggestedTitle = entities['title'] ??
                      entities['item'] ??
                      entities['text'] ??
                      '';
                  final suggestedBody = entities['body'] ?? '';
                  final res = await showDialog<_EditResult>(
                    context: context,
                    builder: (ctx) {
                      final titleCtl =
                          TextEditingController(text: suggestedTitle);
                      final bodyCtl =
                          TextEditingController(text: suggestedBody);
                      return AlertDialog(
                        title: const Text('Confirm action'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              controller: titleCtl,
                              decoration:
                                  const InputDecoration(labelText: 'Title'),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: bodyCtl,
                              decoration: const InputDecoration(
                                  labelText: 'Body (optional)'),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(ctx).pop(null),
                              child: const Text('Cancel')),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(_EditResult(
                                titleCtl.text.trim(),
                                bodyCtl.text.trim() == ''
                                    ? null
                                    : bodyCtl.text.trim())),
                            child: const Text('Confirm'),
                          ),
                        ],
                      );
                    },
                  );

                  if (res == null) return;
                  final overrides = <String, dynamic>{'title': res.title};
                  if (res.body != null)
                    overrides['metadata'] = {'body': res.body};
                  final newProv =
                      widget.manager.accept(p['prov_id'], overrides: overrides);
                  if (newProv != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Accepted')));
                  }
                  _refresh();
                },
                child: const Text('Accept'),
              ),
              TextButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Reject action?'),
                      content: const Text(
                          'Are you sure you want to reject this suggested action?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Reject')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    widget.manager.reject(p['prov_id']);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Rejected')));
                    _refresh();
                  }
                },
                child: const Text('Reject'),
              )
            ]),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text('Details'),
                  content: SingleChildScrollView(child: Text(p.toString())),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
