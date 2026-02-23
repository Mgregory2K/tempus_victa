import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/app_state_scope.dart';
import '../../core/metrics_store.dart';
import '../../core/notification_ingestor.dart';
import '../../core/recycle_bin_store.dart';
import '../../core/signal_item.dart';
import '../../core/signal_mute_store.dart';
import '../../core/signal_store.dart';
import '../../core/task_item.dart';
import '../../core/task_store.dart';
import '../../core/corkboard_store.dart';
import '../room_frame.dart';
import '../theme/tempus_ui.dart';
import '../widgets/signal_detail_sheet.dart';

class SignalBayRoom extends StatefulWidget {
  final String roomName;
  const SignalBayRoom({super.key, required this.roomName});

  @override
  State<SignalBayRoom> createState() => _SignalBayRoomState();
}

class _SignalBayRoomState extends State<SignalBayRoom> with WidgetsBindingObserver {
  List<SignalItem> _signals = const [];
  bool _loading = true;

  Timer? _refreshTimer;

  Set<String> _mutedPkgs = const <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) => _pullNativeSignals());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pullNativeSignals();
    }
  }

  Future<void> _load() async {
    final items = await SignalStore.load();
    final muted = await SignalMuteStore.loadMutedPackages();
    if (!mounted) return;
    setState(() {
      _signals = items;
      _mutedPkgs = muted;
      _loading = false;
    });
    await _pullNativeSignals();
  }

  Future<void> _persist() async => SignalStore.save(_signals);

  String _fingerprint(String pkg, String title, String body) => '$pkg|$title|$body';

  Future<void> _pullNativeSignals() async {
    final native = await NotificationIngestor.fetchAndClearSignals();
    if (native.isEmpty) return;

    final now = DateTime.now();
    final incoming = native.map((m) {
      final createdAt = DateTime.fromMillisecondsSinceEpoch(
        (m['createdAtMs'] is int) ? m['createdAtMs'] as int : (int.tryParse('${m['createdAtMs']}') ?? now.millisecondsSinceEpoch),
      );
      final pkg = (m['packageName'] ?? 'android').toString();
      final title = (m['title'] ?? '').toString().trim();
      final body = (m['body'] ?? '').toString().trim();
      final display = title.isNotEmpty ? title : (body.isNotEmpty ? body : 'Notification');
      final fp = _fingerprint(pkg, display, body);

      return SignalItem(
        id: (m['id'] ?? createdAt.microsecondsSinceEpoch.toString()).toString(),
        createdAt: createdAt,
        source: pkg,
        title: display,
        body: body.isEmpty ? null : body,
        fingerprint: fp,
        lastSeenAt: createdAt,
      );
    }).toList();

    // Merge: dedupe by fingerprint (prefer newest lastSeen), increment count.
    final byFp = <String, SignalItem>{ for (final s in _signals) s.fingerprint : s };
    for (final s in incoming) {
      final existing = byFp[s.fingerprint];
      if (existing == null) {
        byFp[s.fingerprint] = s;
      } else {
        final newerLast = s.lastSeenAt.isAfter(existing.lastSeenAt) ? s.lastSeenAt : existing.lastSeenAt;
        byFp[s.fingerprint] = existing.copyWith(
          lastSeenAt: newerLast,
          count: existing.count + 1,
        );
      }
    }

    // Keep most recent first by lastSeenAt.
    final merged = byFp.values.toList()
      ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));

    // Cap log to keep the app snappy.
    final capped = merged.take(500).toList(growable: false);

    if (!mounted) return;
    setState(() => _signals = capped);
    await _persist();

    await MetricsStore.bump(MetricKeys.signalsIngested, incoming.length);
  }

  Future<void> _toTask(SignalItem s) async {
    final now = DateTime.now();
    final task = TaskItem(id: now.microsecondsSinceEpoch.toString(), title: s.title, createdAt: now);

    final tasks = await TaskStore.load();
    await TaskStore.save([task, ...tasks]);
    AppStateScope.of(context).bumpTasksVersion();

    await _acknowledge(s, true);

    if (!mounted) return;
    AppStateScope.of(context).setSelectedModule('tasks');
  }

  Future<void> _toRecycle(SignalItem s) async {
    final bin = await RecycleBinStore.loadSignals();
    await RecycleBinStore.saveSignals([s, ...bin]);

    setState(() => _signals = _signals.where((x) => x.id != s.id).toList(growable: false));
    await _persist();
  }

  Future<void> _acknowledge(SignalItem s, bool ack) async {
    setState(() {
      _signals = _signals.map((x) => x.fingerprint == s.fingerprint ? x.copyWith(acknowledged: ack) : x).toList(growable: false);
    });
    await _persist();
    if (ack) await MetricsStore.bump(MetricKeys.signalsAcknowledged);
  }

  bool _inInbox(SignalItem s) => !s.acknowledged && !_mutedPkgs.contains(s.source);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inbox = _signals.where(_inInbox).toList(growable: false);
    final log = _signals.where((s) => !_inInbox(s)).toList(growable: false);

    return DefaultTabController(
      length: 2,
      child: RoomFrame(
        title: widget.roomName,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant.withOpacity(.55)),
                ),
                child: const TabBar(
                  tabs: [
                    Tab(text: 'Inbox'),
                    Tab(text: 'Log'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        children: [
                          _buildList(inbox, empty: _emptyInbox(context)),
                          _buildList(log, empty: _emptyLog(context)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<SignalItem> items, {required Widget empty}) {
    if (items.isEmpty) return empty;

    return RefreshIndicator(
      onRefresh: () async {
        await _pullNativeSignals();
        await _load();
      },
      child: ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final s = items[i];
        final cs = Theme.of(ctx).colorScheme;

        final tile = TempusCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(.95),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface)),
                    const SizedBox(height: 4),
                    Text(
                      s.body ?? s.source,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TempusPill(text: s.source),
                        if (s.count > 1) TempusPill(text: '${s.count}×'),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        );

        return Dismissible(
          key: ValueKey('sig_${s.fingerprint}'),
          background: _swipeBg(ctx, Icons.playlist_add, 'Task'),
          secondaryBackground: _swipeBg(ctx, Icons.delete_outline, 'Recycle', right: true),
          confirmDismiss: (dir) async {
            if (dir == DismissDirection.startToEnd) {
              await _showActions(s);
              return false;
            } else {
              await _toRecycle(s);
              return true;
            }
          },
          child: InkWell(
            onTap: () => _openDetails(s),
            borderRadius: BorderRadius.circular(18),
            child: tile,
          ),
        );
      },
      ),
    );
  }

  Widget _swipeBg(BuildContext ctx, IconData icon, String label, {bool right = false}) {
    final cs = Theme.of(ctx).colorScheme;
    return Container(
      alignment: right ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: right ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!right) Icon(icon, color: cs.primary),
          if (!right) const SizedBox(width: 8),
          Text(label, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
          if (right) const SizedBox(width: 8),
          if (right) Icon(icon, color: cs.primary),
        ],
      ),
    );
  }

  Future<void> _showActions(SignalItem s) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.task_alt, color: cs.primary),
                title: const Text('Create Task'),
                subtitle: const Text('Promote this signal into Tasks.'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _toTask(s);
                },
              ),
              ListTile(
                leading: Icon(Icons.push_pin, color: cs.secondary),
                title: const Text('Corkboard It'),
                subtitle: const Text('Pin it as a note (no due date).'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final text = ('${s.title}\n${s.body}'.trim());
                  await CorkboardStore.addText(text);
                  await MetricsStore.inc('corkboardCreated');
                  await _acknowledge(s, true);
                  if (!mounted) return;
                  AppStateScope.of(context).setSelectedModule('corkboard');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openDetails(SignalItem s) async {
    final muted = _mutedPkgs.contains(s.source);
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SignalDetailSheet(
        item: s,
        muted: muted,
        onAcknowledge: (v) async {
          await _acknowledge(s, v);
        },
        onMuteChanged: (v) async {
          final updated = await SignalMuteStore.loadMutedPackages();
          if (!mounted) return;
          setState(() => _mutedPkgs = updated);
        },
      ),
    );
  }

  Widget _emptyInbox(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: TempusCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.radar, size: 30, color: cs.primary),
            const SizedBox(height: 10),
            Text('All clear', style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface)),
            const SizedBox(height: 6),
            Text('Signals are still being logged in the background.', style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _emptyLog(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: TempusCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 30, color: cs.primary),
            const SizedBox(height: 10),
            Text('No history yet', style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface)),
          ],
        ),
      ),
    );
  }
}