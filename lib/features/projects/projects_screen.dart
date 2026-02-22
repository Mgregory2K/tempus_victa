// Tempus Victa - Projects
//
// Projects are durable, local-first artifacts. This screen implements a minimal
// but functional project surface: create, list active, mark done.

import 'package:flutter/material.dart';

import '../../data/repositories/project_repo.dart';
import '../../ui/tempus_scaffold.dart';
import '../../ui/widgets/glass_card.dart';
import '../../widgets/input_composer.dart';

class ProjectsScreen extends StatefulWidget {
  final void Function(int index) onNavigate;
  final int selectedIndex;

  const ProjectsScreen({super.key, required this.onNavigate, required this.selectedIndex});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  Future<void> _create(String title) async {
    final t = title.trim();
    if (t.isEmpty) return;
    await ProjectRepo.instance.create(title: t);
    if (mounted) setState(() {});
  }

  Future<List<_ProjectRow>> _load({required String status}) async {
    final rows = await ProjectRepo.instance.list(status: status);
    return rows.map((p) => _ProjectRow(id: p.id, title: p.title)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return TempusScaffold(
      title: 'Projects',
      selectedIndex: widget.selectedIndex,
      onNavigate: widget.onNavigate,
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Create Project', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                InputComposer(
                  hint: 'New project title… (text or voice)',
                  onSubmit: ({text, transcript}) => _create((text ?? transcript ?? '').trim()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<_ProjectRow>>(
            future: _load(status: 'active'),
            builder: (context, snap) {
              final items = snap.data ?? const <_ProjectRow>[];
              return GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Active', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                        Text('${items.length}', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (items.isEmpty)
                      const Text('No projects yet.')
                    else
                      for (final p in items)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.view_kanban_outlined),
                          title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            tooltip: 'Mark done',
                            icon: const Icon(Icons.check_circle_outline),
                            onPressed: () async {
                              await ProjectRepo.instance.setStatus(p.id, 'done');
                              if (mounted) setState(() {});
                            },
                          ),
                        ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<_ProjectRow>>(
            future: _load(status: 'done'),
            builder: (context, snap) {
              final items = snap.data ?? const <_ProjectRow>[];
              return GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Done', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                        Text('${items.length}', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (items.isEmpty)
                      const Text('No completed projects yet.')
                    else
                      for (final p in items)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.check),
                          title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProjectRow {
  final String id;
  final String title;
  const _ProjectRow({required this.id, required this.title});
}
