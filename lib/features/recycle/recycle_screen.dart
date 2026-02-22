import 'package:flutter/material.dart';

import '../../data/repositories/recycle_repo.dart';
import 'package:mobile/ui/tempus_nav.dart';
import '../../ui/tempus_scaffold.dart';
import '../../widgets/input_composer.dart';

class RecycleScreen extends StatefulWidget {
  const RecycleScreen({super.key, required this.onNavigate, required this.selectedIndex});

  final void Function(int index) onNavigate;
  final int selectedIndex;

  @override
  State<RecycleScreen> createState() => _RecycleScreenState();
}

class _RecycleScreenState extends State<RecycleScreen> {
  @override
  Widget build(BuildContext context) {
    return TempusScaffold(
      title: 'Recycle Bin',
      selectedIndex: widget.selectedIndex,
      onNavigate: widget.onNavigate,
      body: FutureBuilder(
        future: RecycleRepo.instance.listRecycled(),
        builder: (context, snap) {
          final items = snap.data ?? const [];
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return const Center(child: Text('Recycle Bin is empty.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemBuilder: (_, i) {
              final s = items[i];
              final text = (s.transcript?.trim().isNotEmpty ?? false)
                  ? s.transcript!.trim()
                  : (s.text ?? '').trim();
              return Card(
                child: ListTile(
                  title: Text(text.isEmpty ? '(empty)' : text, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('From ${s.source} • ${s.capturedAtUtc.toIso8601String()}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'restore') {
                        await RecycleRepo.instance.restoreToInbox(s.id);
                      } else if (v == 'delete') {
                        await RecycleRepo.instance.hardDelete(s.id);
                      }
                      if (mounted) setState(() {});
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'restore', child: Text('Restore to Inbox')),
                      PopupMenuItem(value: 'delete', child: Text('Delete permanently')),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: items.length,
          );
        },
      ),
    );
  }
}
