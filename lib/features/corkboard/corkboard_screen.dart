// Tempus Vista rebuild - generated 2026-02-21
// Local-first, Android-first.


import 'package:flutter/material.dart';

import '../../data/repositories/cork_repo.dart';
import '../../ui/tempus_scaffold.dart';
import '../../ui/widgets/glass_card.dart';

class CorkboardScreen extends StatefulWidget {
  final void Function(int index)? onNavigate;
  final int? selectedIndex;

  const CorkboardScreen({super.key, this.onNavigate, this.selectedIndex});

  @override
  State<CorkboardScreen> createState() => _CorkboardScreenState();
}

class _CorkboardScreenState extends State<CorkboardScreen> {
  final _controller = TextEditingController();
  late Future<List<Map<String, Object?>>> _future;

  @override
  void initState() {
    super.initState();
    _future = CorkRepo.instance.list();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async => setState(() => _future = CorkRepo.instance.list());

  Future<void> _add() async {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    _controller.clear();
    await CorkRepo.instance.add(t);
    await _refresh();
  }

  Future<void> _delete(String id) async {
    await CorkRepo.instance.delete(id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return TempusScaffold(
      title: 'Corkboard',
      selectedIndex: widget.selectedIndex ?? 4,
      onNavigate: widget.onNavigate ?? (_) {},
      actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            GlassCard(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Drop an idea… (no due date)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(onPressed: _add, icon: const Icon(Icons.add)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snap.data ?? const [];
                  if (items.isEmpty) return const Center(child: Text('No notes yet.'));

                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final r = items[i];
                      final id = r['id'] as String;
                      final text = (r['text'] as String?) ?? '';
                      return GlassCard(
                        child: Row(
                          children: [
                            Expanded(child: Text(text)),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () => _delete(id),
                              icon: const Icon(Icons.delete),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
