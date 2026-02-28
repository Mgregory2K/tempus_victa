import '../../core/unified_index_service.dart';
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
import '../../core/twin_plus/twin_plus_kernel.dart';
import '../../core/twin_plus/twin_event.dart';
import '../../core/signal_intelligence/signal_feedback_store.dart';
import '../../core/signal_intelligence/signal_intelligence.dart';
import '../../core/doctrine/decision_audit_store.dart';
import '../../core/doctrine/routing_counter_store.dart';
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

  Set<String> _mutedPkgs = const <String>{};
  SignalFeedbackSnapshot _feedback = const SignalFeedbackSnapshot();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
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
    await RoutingCounterStore.instance.initialize();
    final items = await SignalStore.load();
    final muted = await SignalMuteStore.loadMutedPackages();
    final feedback = await SignalFeedbackStore.load();
    if (!mounted) return;
    setState(() {
      _signals = items;
      _mutedPkgs = muted;
      _feedback = feedback;
      _loading = false;
    });
    await _pullNativeSignals();
  }

  Future<void> _refresh() async {
    await RoutingCounterStore.instance.initialize();
    // Refresh muted packages + ingest fresh notifications.
    final muted = await SignalMuteStore.loadMutedPackages();
    final feedback = await SignalFeedbackStore.load();
    if (mounted) setState(() => _mutedPkgs = muted);
    if (mounted) setState(() => _feedback = feedback);
    await _pullNativeSignals();
  }

  Future<void> _persist() async => SignalStore.save(_signals);

  Future<void> _auditSignal({
    required SignalItem s,
    required String action,
    required double confidence,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final decisionId = 'sig_${action}_${s.id}_$nowMs';
    await DecisionAuditStore().add(
      DecisionAuditEntry(
        decisionId: decisionId,
        action: action,
        confidence: confidence,
        tsMs: nowMs,
        surface: 'signal_bay',
        entityType: 'signal',
        entityId: s.id,
      ),
    );
  }

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
    final byFp = <String, SignalItem>{for (final s in _signals) s.fingerprint: s};
    final newlyAddedOrUpdated = <SignalItem>[];
    for (final s in incoming) {
      final existing = byFp[s.fingerprint];
      if (existing == null) {
        byFp[s.fingerprint] = s;
        newlyAddedOrUpdated.add(s);
      } else {
        final newerLast = s.lastSeenAt.isAfter(existing.lastSeenAt) ? s.lastSeenAt : existing.lastSeenAt;
        byFp[s.fingerprint] = existing.copyWith(
          lastSeenAt: newerLast,
          count: existing.count + 1,
        );
        newlyAddedOrUpdated.add(byFp[s.fingerprint]!);
      }
    }

    // Keep most recent first by lastSeenAt.
    final merged = byFp.values.toList()..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));

    // Cap log to keep the app snappy.
    final capped = merged.take(500).toList(growable: false);

    if (!mounted) return;
    setState(() => _signals = capped);
    await _persist();

    // Decision audit: record triage for new/updated signals (local-only provenance).
    for (final s in newlyAddedOrUpdated.take(50)) {
      final score = SignalIntelligence.score(s, _feedback).value;
      await _auditSignal(s: s, action: 'triage', confidence: score);
    }

    await MetricsStore.bump(MetricKeys.signalsIngested, incoming.length);
  }

  
  Future<void> _recordRouteDecision(SignalItem s, String routeIntent) async {
    final score = SignalIntelligence.score(s, _feedback).value;
    await RoutingCounterStore.instance.recordRouteDecision('signal_bay', routeIntent);

    // Decision audit (separate from the resulting action).
    await _auditSignal(s: s, action: 'route_decision:$routeIntent', confidence: score);

    // Twin+ observation.
    if (TwinPlusKernel.instance.isReady) {
      TwinPlusKernel.instance.observe(
        TwinEvent.actionPerformed(
          surface: 'signal_bay',
          action: 'route_decision',
          entityType: 'signal',
          entityId: s.id,
          meta: {'routeIntent': routeIntent, 'source': s.source},
          privacy: TwinPrivacy.hashOnly,
          confidence: score,
        ),
      );
    }
  }

  Future<void> _routeByIntent(SignalItem s, String routeIntent) async {
    switch (routeIntent) {
      case RoutingCounterStore.intentRouteToCorkboard:
        await _toCorkboardStub(s);
        return;
      case RoutingCounterStore.intentRouteToRecycle:
        await _toRecycle(s);
        return;
      case RoutingCounterStore.intentRouteToAcknowledge:
        await _acknowledge(s, true);
        return;
      case RoutingCounterStore.intentRouteToTask:
      default:
        await _toTask(s);
        return;
    }
  }
Future<void> _toTask(SignalItem s) async {
    final now = DateTime.now();
    final task = TaskItem(id: now.microsecondsSinceEpoch.toString(), title: s.title, createdAt: now);

    final tasks = await TaskStore.load();
    await TaskStore.save([task, ...tasks]);
    await UnifiedIndexService.addEntry(id: task.id, type: 'task', title: task.title);
    AppStateScope.of(context).bumpTasksVersion();

    await _acknowledge(s, true);

    // Decision audit for provenance.
    final score = SignalIntelligence.score(s, _feedback).value;
    await _auditSignal(s: s, action: 'promote_task', confidence: score);

    // Reinforce: promoted to task.
    await SignalFeedbackStore.bumpSource(s.source, 'promoted');
    await SignalFeedbackStore.bumpFingerprint(s.fingerprint, 'promoted');
    final nextFeedback = await SignalFeedbackStore.load();
    if (mounted) setState(() => _feedback = nextFeedback);
    if (TwinPlusKernel.instance.isReady) {
      TwinPlusKernel.instance.observe(
        TwinEvent.actionPerformed(
          surface: 'signal_bay',
          action: 'promote_task',
          entityType: 'signal',
          entityId: s.id,
          meta: {'source': s.source, 'title': s.title},
          privacy: TwinPrivacy.hashOnly,
        ),
      );
    }

    if (!mounted) return;
    AppStateScope.of(context).setSelectedModule('tasks');
  }

  Future<void> _toCorkboardStub(SignalItem s) async {
    // Your current zip has corkboard as a PlaceholderRoom.
    // We still provide the UX action now: mark it acknowledged and jump to Corkboard module.
    await _acknowledge(s, true);

    final score = SignalIntelligence.score(s, _feedback).value;
    await _auditSignal(s: s, action: 'promote_corkboard', confidence: score);

    // Reinforce: promoted to corkboard (stub for now).
    await SignalFeedbackStore.bumpSource(s.source, 'promoted');
    await SignalFeedbackStore.bumpFingerprint(s.fingerprint, 'promoted');
    final nextFeedback = await SignalFeedbackStore.load();
    if (mounted) setState(() => _feedback = nextFeedback);
    if (TwinPlusKernel.instance.isReady) {
      TwinPlusKernel.instance.observe(
        TwinEvent.actionPerformed(
          surface: 'signal_bay',
          action: 'promote_corkboard',
          entityType: 'signal',
          entityId: s.id,
          meta: {'source': s.source, 'title': s.title},
          privacy: TwinPrivacy.hashOnly,
        ),
      );
    }
    if (!mounted) return;
    AppStateScope.of(context).setSelectedModule('corkboard');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Corkboard capture queued (Corkboard module is placeholder in this build).')),
    );
  }

  Future<void> _toRecycle(SignalItem s) async {
    final bin = await RecycleBinStore.loadSignals();
    await RecycleBinStore.saveSignals([s, ...bin]);

    setState(() => _signals = _signals.where((x) => x.fingerprint != s.fingerprint).toList(growable: false));
    await _persist();

    final score = SignalIntelligence.score(s, _feedback).value;
    await _auditSignal(s: s, action: 'recycle', confidence: score);

    await SignalFeedbackStore.bumpSource(s.source, 'recycled');
    await SignalFeedbackStore.bumpFingerprint(s.fingerprint, 'recycled');
    final nextFeedback = await SignalFeedbackStore.load();
    if (mounted) setState(() => _feedback = nextFeedback);
    if (TwinPlusKernel.instance.isReady) {
      TwinPlusKernel.instance.observe(
        TwinEvent.actionPerformed(
          surface: 'signal_bay',
          action: 'recycle',
          entityType: 'signal',
          entityId: s.id,
          meta: {'source': s.source},
          privacy: TwinPrivacy.hashOnly,
        ),
      );
    }
  }

  Future<void> _acknowledge(SignalItem s, bool ack) async {
    setState(() {
      _signals = _signals.map((x) => x.fingerprint == s.fingerprint ? x.copyWith(acknowledged: ack) : x).toList(growable: false);
    });
    await _persist();
    if (ack) await MetricsStore.bump(MetricKeys.signalsAcknowledged);

    if (ack) {
      await SignalFeedbackStore.bumpSource(s.source, 'acknowledged');
      await SignalFeedbackStore.bumpFingerprint(s.fingerprint, 'acknowledged');
      final nextFeedback = await SignalFeedbackStore.load();
      if (mounted) setState(() => _feedback = nextFeedback);
      if (TwinPlusKernel.instance.isReady) {
        TwinPlusKernel.instance.observe(
          TwinEvent.actionPerformed(
            surface: 'signal_bay',
            action: 'acknowledge',
            entityType: 'signal',
            entityId: s.id,
            meta: {'source': s.source},
            privacy: TwinPrivacy.hashOnly,
          ),
        );
      }

      final score = SignalIntelligence.score(s, _feedback).value;
      await _auditSignal(s: s, action: 'acknowledge', confidence: score);
    }
  }

  bool _inInbox(SignalItem s) => !s.acknowledged && !_mutedPkgs.contains(s.source);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inbox = _signals.where(_inInbox).toList(growable: false)
      ..sort((a, b) {
        final sa = SignalIntelligence.score(a, _feedback).value;
        final sb = SignalIntelligence.score(b, _feedback).value;
        final c = sb.compareTo(sa);
        if (c != 0) return c;
        return b.lastSeenAt.compareTo(a.lastSeenAt);
      });
    final log = _signals.where((s) => !_inInbox(s)).toList(growable: false)
      ..sort((a, b) {
        final sa = SignalIntelligence.score(a, _feedback).value;
        final sb = SignalIntelligence.score(b, _feedback).value;
        final c = sb.compareTo(sa);
        if (c != 0) return c;
        return b.lastSeenAt.compareTo(a.lastSeenAt);
      });

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
                          _buildRefreshableList(inbox, empty: _emptyInbox(context)),
                          _buildRefreshableList(log, empty: _emptyLog(context)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshableList(List<SignalItem> items, {required Widget empty}) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [const SizedBox(height: 140), Center(child: empty)],
            )
          : _buildList(items),
    );
  }

  Widget _buildList(List<SignalItem> items) {
    return ListView.separated(
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
          background: _swipeBg(ctx, Icons.keyboard_arrow_right, 'Action'),
          secondaryBackground: _swipeBg(ctx, Icons.delete_outline, 'Recycle', right: true),
          confirmDismiss: (dir) async {
            if (dir == DismissDirection.startToEnd) {
              final training = RoutingCounterStore.instance.isTrainingWindow('signal_bay');
              if (training) {
                await _showActions(ctx, s);
                return false;
              }
              final learned = RoutingCounterStore.instance.learnedDefaultRoute('signal_bay');
              await _recordRouteDecision(s, learned);
              await _routeByIntent(s, learned);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Routed automatically (learned): ${_prettyRouteLabel(learned)}')),
                );
              }
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
    );
  }

  Future<void> _showActions(BuildContext ctx, SignalItem s) async {
    await showModalBottomSheet<void>(
      context: ctx,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TempusCard(
                child: ListTile(
                  leading: const Icon(Icons.playlist_add),
                  title: const Text('Create Task'),
                  subtitle: const Text('Promote this signal into Tasks.'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _recordRouteDecision(s, RoutingCounterStore.intentRouteToTask);
                    await _toTask(s);
                  },
                ),
              ),
              const SizedBox(height: 10),
              TempusCard(
                child: ListTile(
                  leading: const Icon(Icons.note_alt_outlined),
                  title: const Text('Corkboard It'),
                  subtitle: const Text('Pin for later review (placeholder in this build).'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _recordRouteDecision(s, RoutingCounterStore.intentRouteToCorkboard);
                    await _toCorkboardStub(s);
                  },
                ),
              ),
            ],
          ),
        ),
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

  Future<void> _openDetails(SignalItem s) async {
    // Lightweight reinforcement: opening details counts as engagement.
    await SignalFeedbackStore.bumpSource(s.source, 'opened');
    await SignalFeedbackStore.bumpFingerprint(s.fingerprint, 'opened');
    final nextFeedback = await SignalFeedbackStore.load();
    if (mounted) setState(() => _feedback = nextFeedback);
    if (TwinPlusKernel.instance.isReady) {
      TwinPlusKernel.instance.observe(
        TwinEvent.actionPerformed(
          surface: 'signal_bay',
          action: 'open_details',
          entityType: 'signal',
          entityId: s.id,
          meta: {'source': s.source},
          privacy: TwinPrivacy.hashOnly,
          confidence: 0.85,
        ),
      );
    }

    final score = SignalIntelligence.score(s, _feedback).value;
    await _auditSignal(s: s, action: 'open_details', confidence: score);

    final muted = _mutedPkgs.contains(s.source);
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SignalDetailSheet(
        item: s,
        muted: muted,
        showRouting: RoutingCounterStore.instance.isTrainingWindow('signal_bay'),
        onRouteToTask: () async {
          Navigator.of(context).pop();
          await _recordRouteDecision(s, RoutingCounterStore.intentRouteToTask);
          await _toTask(s);
        },
        onRouteToCorkboard: () async {
          Navigator.of(context).pop();
          await _recordRouteDecision(s, RoutingCounterStore.intentRouteToCorkboard);
          await _toCorkboardStub(s);
        },
        onRouteToRecycle: () async {
          Navigator.of(context).pop();
          await _recordRouteDecision(s, RoutingCounterStore.intentRouteToRecycle);
          await _toRecycle(s);
        },
        onAcknowledge: (v) async {
          await _acknowledge(s, v);
        },
        onMuteChanged: (v) async {
          final updated = await SignalMuteStore.loadMutedPackages();
          if (v) {
            await SignalFeedbackStore.bumpSource(s.source, 'muted');
            await SignalFeedbackStore.bumpFingerprint(s.fingerprint, 'muted');
          }
          final nextFeedback = await SignalFeedbackStore.load();
          if (!mounted) return;
          setState(() {
            _mutedPkgs = updated;
            _feedback = nextFeedback;
          });
          if (TwinPlusKernel.instance.isReady) {
            TwinPlusKernel.instance.observe(
              TwinEvent.actionPerformed(
                surface: 'signal_bay',
                action: v ? 'mute_source' : 'unmute_source',
                entityType: 'signal_source',
                entityId: s.source,
                privacy: TwinPrivacy.hashOnly,
              ),
            );
          }
        },
      ),
    );
  }

  Widget _emptyInbox(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TempusCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.radar, size: 30, color: cs.primary),
          const SizedBox(height: 10),
          Text('All clear', style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface)),
          const SizedBox(height: 6),
          Text('Pull down to refresh.', style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  
  String _prettyRouteLabel(String intent) {
    final s = intent.trim();
    if (s.isEmpty) return 'Unknown';
    switch (s) {
      case 'task':
        return 'Task';
      case 'corkboard':
        return 'Corkboard';
      case 'quote':
        return 'Quote';
      case 'project':
        return 'Project';
      case 'recycle':
        return 'Recycle';
      case 'ignore':
        return 'Ignore';
      case 'signal_bay':
        return 'Signal Bay';
      default:
        final parts = s.split(RegExp(r'[_\-\s]+')).where((p) => p.isNotEmpty).toList();
        if (parts.isEmpty) return s;
        return parts.map((p) => p[0].toUpperCase() + p.substring(1)).join(' ');
    }
  }

Widget _emptyLog(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TempusCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 30, color: cs.primary),
          const SizedBox(height: 10),
          Text('No history yet', style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface)),
        ],
      ),
    );
  }
}
