import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/app_state_scope.dart';
import '../../core/project_item.dart';
import '../../core/project_store.dart';
import '../../core/recycle_bin_store.dart';
import '../../core/task_item.dart';
import '../../core/task_store.dart';
import '../../core/metrics_store.dart';
import '../../core/twin_plus/twin_plus_scope.dart';
import '../../core/twin_plus/twin_event.dart';
import '../room_frame.dart';
import '../theme/tv_textfield.dart';
import '../../services/voice/voice_service.dart';
import '../../core/app_settings_store.dart';
import '../widgets/dev_trace_panel.dart';

class TasksRoom extends StatefulWidget {
  final String roomName;
  const TasksRoom({super.key, required this.roomName});

  @override
  State<TasksRoom> createState() => _TasksRoomState();
}

class _TasksRoomState extends State<TasksRoom> {
  Future<List<TaskItem>> _load() => TaskStore.load();

  bool _devMode = false;
  List<String> _devTrace = const [];

  @override
  void initState() {
    super.initState();
    _loadDevMode();
  }

  Future<void> _loadDevMode() async {
    final v = await AppSettingsStore().loadDevMode();
    if (!mounted) return;
    setState(() => _devMode = v);
  }


  Future<void> _createManualTask() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New task'),
        content: TvTextField(
          controller: controller,
          autofocus: true,
          hintText: 'Type a task...',
          twinSurface: 'tasks',
          twinFieldId: 'new_task',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );

    if (text == null || text.isEmpty) return;

    final now = DateTime.now();
    final t = TaskItem(
      id: now.microsecondsSinceEpoch.toString(),
      createdAt: now,
      title: text,
      transcript: null,
      audioPath: null,
      projectId: null,
    );

    final tasks = await TaskStore.load();
    await TaskStore.save([t, ...tasks]);

    await MetricsStore.inc(TvMetrics.tasksCreatedManual);

    // Twin+ explicit action signal (local, inspectable)
    final kernel = TwinPlusScope.of(context);
    kernel.observe(TwinEvent.actionPerformed(surface: 'tasks', action: 'task_created', entityType: 'task', entityId: t.id));

    if (!mounted) return;
    AppStateScope.of(context).bumpTasksVersion();
  }


  Future<void> _createVoiceTaskQuick() async {
    String live = '';
    bool listening = true;

    // Start listening immediately.
    await VoiceService.instance.start(
      onPartial: (p) {
        live = p;
      },
    );

    final transcript = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          // lightweight ticker to repaint while voice updates (no assumptions about stream)
          Future.delayed(const Duration(milliseconds: 250), () {
            if (listening) setLocal(() {});
          });

          return AlertDialog(
            title: const Text('Voice task'),
            content: SizedBox(
              width: double.maxFinite,
              child: Text(
                live.trim().isEmpty ? 'Listening…' : live.trim(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  listening = false;
                  await VoiceService.instance.stop(finalTranscript: '');
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  listening = false;
                  final res = await VoiceService.instance.stop(finalTranscript: live);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx, res.transcript);
                },
                child: const Text('Create'),
              ),
            ],
          );
        });
      },
    );

    if (transcript == null) return;
    final ttxt = transcript.trim();
    if (ttxt.isEmpty) return;

    final now = DateTime.now();
    final task = TaskItem(
      id: now.microsecondsSinceEpoch.toString(),
      createdAt: now,
      title: TaskItem.titleFromTranscript(ttxt, maxWords: 6),
      transcript: ttxt,
      audioDurationMs: null, // VoiceService duration is emitted in TvTextField path; Bridge handles audio duration.
      audioPath: null,
      projectId: null,
    );

    final tasks = await TaskStore.load();
    await TaskStore.save([task, ...tasks]);
    await MetricsStore.inc(TvMetrics.tasksCreatedVoice);

    final kernel = TwinPlusScope.of(context);
    kernel.observe(
      TwinEvent.actionPerformed(surface: 'tasks', action: 'task_created_voice', entityType: 'task', entityId: task.id),
    );

    if (!mounted) return;
    AppStateScope.of(context).bumpTasksVersion();
  }


  Future<void> _renameTask(TaskItem task) async {
    final controller = TextEditingController(text: task.title);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename task'),
        content: TvTextField(
          controller: controller,
          autofocus: true,
          hintText: 'Task title',
          twinSurface: 'tasks',
          twinFieldId: 'rename_task',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;

    final tasks = await TaskStore.load();
    final idx = tasks.indexWhere((t) => t.id == task.id);
    if (idx < 0) return;

    final updated = List<TaskItem>.of(tasks);
    updated[idx] = updated[idx].copyWith(title: text.trim());
    await TaskStore.save(updated);

    if (!mounted) return;
    AppStateScope.of(context).bumpTasksVersion();
  }

  Future<void> _trashTask(TaskItem task) async {
    // Remove from tasks
    final tasks = await TaskStore.load();
    final updatedTasks = List<TaskItem>.of(tasks)..removeWhere((t) => t.id == task.id);
    await TaskStore.save(updatedTasks);

    // Add to recycle bin (tasks)
    final bin = await RecycleBinStore.loadTasks();
    await RecycleBinStore.saveTasks([task, ...bin]);

    if (!mounted) return;
    // Twin+
    TwinPlusScope.of(context).observe(TwinEvent.actionPerformed(surface: 'tasks', action: 'task_renamed', entityType: 'task', entityId: task.id));

    if (!mounted) return;
    AppStateScope.of(context).bumpTasksVersion();
  }

  Future<void> _attachToProject(TaskItem task) async {
    final projects = await ProjectStore.load();
    if (!mounted) return;

    final selected = await showModalBottomSheet<_ProjectPickResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ProjectPickerSheet(projects: projects),
    );

    if (selected == null) return;

    String? projectId = selected.projectId;

    // Create new project if requested
    if (selected.createNewName != null) {
      final now = DateTime.now();
      final p = ProjectItem(
        id: now.microsecondsSinceEpoch.toString(),
        createdAt: now,
        name: selected.createNewName!,
      );
      await ProjectStore.save([p, ...projects]);
      projectId = p.id;
    }

    if (projectId == null) return;

    final tasks = await TaskStore.load();
    final idx = tasks.indexWhere((t) => t.id == task.id);
    if (idx < 0) return;

    final updated = List<TaskItem>.of(tasks);
    updated[idx] = updated[idx].copyWith(projectId: projectId);
    await TaskStore.save(updated);

    if (!mounted) return;
    AppStateScope.of(context).bumpTasksVersion();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attached to project')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reading this makes the widget rebuild whenever tasksVersion changes.
    final _ = AppStateScope.of(context).tasksVersion;

    return RoomFrame(
      title: widget.roomName,
      fab: FloatingActionButton(
        onPressed: _createManualTask,
        child: const Icon(Icons.add),
      ),
      child: Column(
        children: [
          if (_devMode) DevTracePanel(lines: _devTrace),
          Expanded(
            child: FutureBuilder<List<TaskItem>>(
        future: _load(),
        builder: (context, snap) {
          final tasks = snap.data ?? const <TaskItem>[];

          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (tasks.isEmpty) {
            return const Center(child: Text('No tasks yet. Tap + to create one.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final t = tasks[i];
              final hasAudio = t.audioPath != null && t.audioPath!.isNotEmpty;
              final subtitle = hasAudio
                  ? (t.transcript?.trim().isNotEmpty == true
                      ? TaskItem.titleFromTranscript(t.transcript, maxWords: 6)
                      : 'Voice capture (tap to label)')
                  : (t.transcript?.trim().isNotEmpty == true ? 'Text' : '');

              return Dismissible(
                key: ValueKey('task_${t.id}'),
                background: _SwipeBg(
                  icon: Icons.folder_rounded,
                  label: 'Attach to project',
                  alignLeft: true,
                ),
                secondaryBackground: _SwipeBg(
                  icon: Icons.delete_rounded,
                  label: 'Recycle',
                  alignLeft: false,
                ),
                confirmDismiss: (dir) async {
                  if (dir == DismissDirection.startToEnd) {
                    // Right swipe: attach, but do NOT dismiss.
                    await _attachToProject(t);
                    return false;
                  }
                  if (dir == DismissDirection.endToStart) {
                    // Left swipe: trash/recycle
                    return true;
                  }
                  return false;
                },
                onDismissed: (_) async {
                  await _trashTask(t);
                },
                child: ListTile(
                  leading: Icon(hasAudio ? Icons.mic_rounded : Icons.task_alt_rounded),
                  title: Text(t.title),
                  subtitle: subtitle.isEmpty ? null : Text(subtitle),
                  trailing: IconButton(
                    tooltip: 'Rename',
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () => _renameTask(t),
                  ),
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => _TaskDetail(task: t),
                  ),
                ),
              );
            },
          );
        },
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool alignLeft;

  const _SwipeBg({
    required this.icon,
    required this.label,
    required this.alignLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: alignLeft ? Colors.blue.withOpacity(0.18) : Colors.red.withOpacity(0.25),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisAlignment: alignLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (alignLeft) ...[
            Icon(icon),
            const SizedBox(width: 8),
            Text(label),
          ] else ...[
            Text(label),
            const SizedBox(width: 8),
            Icon(icon),
          ],
        ],
      ),
    );
  }
}

class _ProjectPickResult {
  final String? projectId;
  final String? createNewName;
  const _ProjectPickResult.select(this.projectId) : createNewName = null;
  const _ProjectPickResult.create(this.createNewName) : projectId = null;
}

class _ProjectPickerSheet extends StatefulWidget {
  final List<ProjectItem> projects;
  const _ProjectPickerSheet({required this.projects});

  @override
  State<_ProjectPickerSheet> createState() => _ProjectPickerSheetState();
}

class _ProjectPickerSheetState extends State<_ProjectPickerSheet> {
  final _newController = TextEditingController();

  @override
  void dispose() {
    _newController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Attach to project',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.projects.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No projects yet. Create one below.'),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.projects.length,
                  itemBuilder: (context, i) {
                    final p = widget.projects[i];
                    return ListTile(
                      leading: const Icon(Icons.folder_rounded),
                      title: Text(p.name),
                      onTap: () => Navigator.pop(context, _ProjectPickResult.select(p.id)),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Or create new',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 6),
            TvTextField(
              controller: _newController,
              hintText: 'New project name',
              twinSurface: 'tasks',
              twinFieldId: 'new_project_name',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Create & attach'),
                    onPressed: () {
                      final name = _newController.text.trim();
                      if (name.isEmpty) return;
                      Navigator.pop(context, _ProjectPickResult.create(name));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskDetail extends StatefulWidget {
  final TaskItem task;
  const _TaskDetail({required this.task});

  @override
  State<_TaskDetail> createState() => _TaskDetailState();
}

class _TaskDetailState extends State<_TaskDetail> {
  final _player = AudioPlayer();
  bool _ready = false;
  bool _transcriptOpen = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final path = widget.task.audioPath;
    if (path != null && path.isNotEmpty && await File(path).exists()) {
      await _player.setFilePath(path);
      setState(() => _ready = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Created: ${t.createdAt.toLocal()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (_ready) _playerControls(context) else const Text('No audio attached.'),
            const SizedBox(height: 12),
            Divider(color: Theme.of(context).dividerColor),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Transcript'),
              subtitle: Text(
                (t.transcript == null || t.transcript!.trim().isEmpty)
                    ? 'Not transcribed yet.'
                    : 'Tap to view',
              ),
              trailing: Icon(_transcriptOpen ? Icons.expand_less : Icons.expand_more),
              onTap: () => setState(() => _transcriptOpen = !_transcriptOpen),
            ),
            if (_transcriptOpen)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  (t.transcript == null || t.transcript!.trim().isEmpty)
                      ? '—'
                      : t.transcript!,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _playerControls(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snap) {
        final playing = snap.data?.playing ?? false;

        return Row(
          children: [
            IconButton.filled(
              onPressed: () async {
                if (playing) {
                  await _player.pause();
                } else {
                  await _player.play();
                }
              },
              icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StreamBuilder<Duration?>(
                stream: _player.durationStream,
                builder: (context, dSnap) {
                  final dur = dSnap.data ?? Duration.zero;
                  return StreamBuilder<Duration>(
                    stream: _player.positionStream,
                    builder: (context, pSnap) {
                      final pos = pSnap.data ?? Duration.zero;
                      final max = dur.inMilliseconds == 0 ? 1 : dur.inMilliseconds;
                      final v = (pos.inMilliseconds / max).clamp(0.0, 1.0);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(value: v),
                          const SizedBox(height: 4),
                          Text('${_fmt(pos)} / ${_fmt(dur)}', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    final ss = s.toString().padLeft(2, '0');
    return '$m:$ss';
  }
}
