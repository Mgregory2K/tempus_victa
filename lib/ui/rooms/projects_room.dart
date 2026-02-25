import 'package:flutter/material.dart';

import '../../core/metrics_store.dart';
import '../../core/twin_plus/twin_plus_scope.dart';
import '../../core/twin_plus/twin_event.dart';
import '../../core/project_item.dart';
import '../../core/project_store.dart';
import '../../core/unified_index_service.dart';
import '../room_frame.dart';
import '../theme/tempus_ui.dart';
import '../theme/tv_textfield.dart';

class ProjectsRoom extends StatefulWidget {
  final String roomName;
  const ProjectsRoom({super.key, required this.roomName});

  @override
  State<ProjectsRoom> createState() => _ProjectsRoomState();
}

class _ProjectsRoomState extends State<ProjectsRoom> {
  List<ProjectItem> _projects = const [];
  bool _loading = true;
  String _query = '';
  int _view = 0; // 0 = Projects, 1 = Board (stub)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await ProjectStore.load();
    if (!mounted) return;
    setState(() {
      _projects = items;
      _loading = false;
    });
  }

  Future<void> _persist() => ProjectStore.save(_projects);

  Future<void> _createProject() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New project'),
        content: TvTextField(
          controller: controller,
          twinSurface: 'projects',
          twinFieldId: 'new_project_name',
          autofocus: true,
          hintText: 'Project name',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    final now = DateTime.now();
    final p = ProjectItem(id: now.microsecondsSinceEpoch.toString(), createdAt: now, name: name);
    setState(() => _projects = [p, ..._projects]);
    await _persist();
    await UnifiedIndexService.upsert(id: p.id, type: 'project', title: p.name);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final filtered = _projects
        .where((p) => _query.trim().isEmpty || p.name.toLowerCase().contains(_query.trim().toLowerCase()))
        .toList(growable: false);

    return RoomFrame(
      title: widget.roomName,
      fab: FloatingActionButton(
        heroTag: 'projects_add',
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        onPressed: _createProject,
        child: const Icon(Icons.add),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Quick search',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 10),
                TempusPill(
                  text: _view == 0 ? 'Projects' : 'Board',
                  onTap: () => setState(() => _view = _view == 0 ? 1 : 0),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _quickActions(context),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_view == 0 ? _projectsList(filtered) : _boardStub(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget action(String label, IconData icon, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: () async {
            await MetricsStore.bump(MetricKeys.projectsOpened);
            onTap();
          },
          borderRadius: BorderRadius.circular(18),
          child: TempusCard(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: cs.primary),
                const SizedBox(height: 8),
                Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        action('Create Issue', Icons.add_circle_outline, _createProject),
        const SizedBox(width: 10),
        action('My Board', Icons.view_kanban_outlined, () => setState(() => _view = 1)),
        const SizedBox(width: 10),
        action('My Issues', Icons.list_alt_outlined, () {}),
      ],
    );
  }

  Widget _projectsList(List<ProjectItem> items) {
    if (items.isEmpty) {
      return const Center(child: Text('No projects yet'));
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final p = items[i];
        final cs = Theme.of(ctx).colorScheme;
        final key = _projectKey(p.name);

        return InkWell(
          onTap: () async {
            await MetricsStore.bump(MetricKeys.projectsOpened);
            if (!mounted) return;
            showModalBottomSheet(
              context: ctx,
              showDragHandle: true,
              builder: (_) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: cs.onSurface)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        TempusPill(text: 'Backlog'),
                        TempusPill(text: 'In Progress'),
                        TempusPill(text: 'Done'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Project details view will live here (board + list).', style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(18),
          child: TempusCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: cs.primary.withOpacity(.14),
                    border: Border.all(color: cs.primary.withOpacity(.45)),
                  ),
                  child: Center(
                    child: Text(
                      key,
                      style: TextStyle(fontWeight: FontWeight.w900, color: cs.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: TextStyle(fontWeight: FontWeight.w900, color: cs.onSurface)),
                      const SizedBox(height: 4),
                      Text('Tap for board & issues', style: TextStyle(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _boardStub(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        _kanbanCol(context, 'Backlog', cs.surface),
        _kanbanCol(context, 'In Progress', cs.surface),
        _kanbanCol(context, 'Done', cs.surface),
      ],
    );
  }

  Widget _kanbanCol(BuildContext context, String title, Color bg) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      child: TempusCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: cs.onSurface)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  _issueCard(context, 'Placeholder issue', 'Waiting', Icons.schedule),
                  const SizedBox(height: 10),
                  _issueCard(context, 'Another item', 'Open', Icons.radio_button_unchecked),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _issueCard(BuildContext context, String title, String status, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withOpacity(.55)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface))),
            TempusPill(text: status),
          ],
        ),
      ),
    );
  }

  String _projectKey(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'PRJ';
    if (parts.length == 1) return parts.first.substring(0, parts.first.length >= 3 ? 3 : parts.first.length).toUpperCase();
    final a = parts.first[0];
    final b = parts[1][0];
    return ('$a$b').toUpperCase();
  }
}
