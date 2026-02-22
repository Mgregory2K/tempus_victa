import 'package:flutter/material.dart';

import '../../core/project_item.dart';
import '../../core/project_store.dart';
import '../room_frame.dart';

class ProjectsRoom extends StatefulWidget {
  final String roomName;
  const ProjectsRoom({super.key, required this.roomName});

  @override
  State<ProjectsRoom> createState() => _ProjectsRoomState();
}

class _ProjectsRoomState extends State<ProjectsRoom> {
  List<ProjectItem> _projects = const [];
  bool _loading = true;

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
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Project name'),
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
  }

  Future<void> _delete(ProjectItem item) async {
    setState(() => _projects = List.of(_projects)..removeWhere((x) => x.id == item.id));
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    return RoomFrame(
      title: widget.roomName,
      fab: FloatingActionButton(
        onPressed: _createProject,
        child: const Icon(Icons.add),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? const Center(child: Text('No projects yet. Tap + to create one.'))
              : ListView.builder(
                  itemCount: _projects.length,
                  itemBuilder: (context, i) {
                    final p = _projects[i];
                    return ListTile(
                      leading: const Icon(Icons.folder_rounded),
                      title: Text(p.name),
                      subtitle: Text(p.createdAt.toLocal().toString()),
                      trailing: IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _delete(p),
                      ),
                    );
                  },
                ),
    );
  }
}
