import 'package:flutter/material.dart';

import '../../core/app_state_scope.dart';
import '../../core/notification_ingestor.dart';
import '../../core/recycle_bin_store.dart';
import '../../core/signal_item.dart';
import '../../core/signal_store.dart';
import '../../core/task_item.dart';
import '../../core/task_store.dart';
import '../room_frame.dart';

class SignalBayRoom extends StatefulWidget {
  final String roomName;
  const SignalBayRoom({super.key, required this.roomName});

  @override
  State<SignalBayRoom> createState() => _SignalBayRoomState();
}

class _SignalBayRoomState extends State<SignalBayRoom> with WidgetsBindingObserver {
  List<SignalItem> _signals = const [];
  bool _loading = true;

  bool _notifAccessEnabled = false;
  bool _checkingAccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // Keep this check for now (so we can show a lightweight status in the empty state),
    // but we no longer show the big settings card in Signal Bay.
    _refreshNotifEnabled();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotifEnabled();
      _pullNativeSignals();
    }
  }

  Future<void> _load() async {
    final items = await SignalStore.load();
    if (!mounted) return;
    setState(() {
      _signals = items;
      _loading = false;
    });
    await _pullNativeSignals();
  }

  Future<void> _persist() async => SignalStore.save(_signals);

  Future<void> _refreshNotifEnabled() async {
    setState(() => _checkingAccess = true);
    final enabled = await NotificationIngestor.isNotificationAccessEnabled();
    if (!mounted) return;
    setState(() {
      _notifAccessEnabled = enabled;
      _checkingAccess = false;
    });
  }

  Future<void> _pullNativeSignals() async {
    final native = await NotificationIngestor.fetchAndClearSignals();
    if (native.isEmpty) return;

    final now = DateTime.now();
    final incoming = native.map((m) {
      final createdAt = DateTime.fromMillisecondsSinceEpoch(
        (m['createdAtMs'] is int)
            ? m['createdAtMs'] as int
            : (int.tryParse('${m['createdAtMs']}') ?? now.millisecondsSinceEpoch),
      );
      final pkg = (m['packageName'] ?? 'android').toString();
      final title = (m['title'] ?? '').toString().trim();
      final body = (m['body'] ?? '').toString().trim();
      final display = title.isNotEmpty ? title : (body.isNotEmpty ? body : 'Notification');

      return SignalItem(
        id: (m['id'] ?? createdAt.microsecondsSinceEpoch.toString()).toString(),
        createdAt: createdAt,
        source: pkg,
        title: display,
        body: body.isEmpty ? null : body,
      );
    }).toList();

    final existingIds = _signals.map((s) => s.id).toSet();
    final merged = <SignalItem>[
      ...incoming.where((s) => !existingIds.contains(s.id)),
      ..._signals,
    ];

    if (!mounted) return;
    setState(() => _signals = merged);
    await _persist();
  }

  Future<void> _toTask(SignalItem s) async {
    final now = DateTime.now();
    final task = TaskItem(
      id: now.microsecondsSinceEpoch.toString(),
      title: s.title,
      createdAt: now,
    );

    final tasks = await TaskStore.load();
    await TaskStore.save([task, ...tasks]);
    AppStateScope.of(context).bumpTasksVersion();

    setState(() => _signals = _signals.where((x) => x.id != s.id).toList(growable: false));
    await _persist();

    if (!mounted) return;
    AppStateScope.of(context).setSelectedModule('tasks');
  }

  Future<void> _toRecycle(SignalItem s) async {
    final bin = await RecycleBinStore.loadSignals();
    await RecycleBinStore.saveSignals([s, ...bin]);

    setState(() => _signals = _signals.where((x) => x.id != s.id).toList(growable: false));
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    return RoomFrame(
      title: widget.roomName,
      child: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _signals.isEmpty
                    ? _RadarEmpty(
                        accessEnabled: _notifAccessEnabled,
                        checkingAccess: _checkingAccess,
                        onRefresh: () async {
                          await _refreshNotifEnabled();
                          await _pullNativeSignals();
                        },
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                        itemBuilder: (context, i) {
                          final s = _signals[i];
                          return Dismissible(
                            key: ValueKey(s.id),
                            background: _SwipeBg(
                              icon: Icons.delete_outline_rounded,
                              label: 'Recycle',
                              alignRight: false,
                            ),
                            secondaryBackground: _SwipeBg(
                              icon: Icons.add_task_rounded,
                              label: 'Task',
                              alignRight: true,
                            ),
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.startToEnd) {
                                await _toRecycle(s);
                              } else {
                                await _toTask(s);
                              }
                              return true;
                            },
                            child: _SignalTile(s: s),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemCount: _signals.length,
                      ),
          ),
        ],
      ),
    );
  }
}

class _SignalTile extends StatelessWidget {
  final SignalItem s;
  const _SignalTile({required this.s});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.18)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  s.source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.65),
                  ),
                ),
              ),
              Text(
                _fmtTime(s.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.65),
                ),
              ),
            ],
          ),
          if ((s.body ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              s.body!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool alignRight;
  const _SwipeBg({required this.icon, required this.label, required this.alignRight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final align = alignRight ? Alignment.centerRight : Alignment.centerLeft;
    final pad = alignRight ? const EdgeInsets.only(right: 18) : const EdgeInsets.only(left: 18);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.12)),
      ),
      alignment: align,
      padding: pad,
      child: Row(
        mainAxisAlignment: alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!alignRight) Icon(icon, size: 18),
          if (!alignRight) const SizedBox(width: 8),
          Text(label, style: theme.textTheme.titleSmall),
          if (alignRight) const SizedBox(width: 8),
          if (alignRight) Icon(icon, size: 18),
        ],
      ),
    );
  }
}

class _RadarEmpty extends StatefulWidget {
  final bool accessEnabled;
  final bool checkingAccess;
  final VoidCallback onRefresh;
  const _RadarEmpty({
    required this.accessEnabled,
    required this.checkingAccess,
    required this.onRefresh,
  });

  @override
  State<_RadarEmpty> createState() => _RadarEmptyState();
}

class _RadarEmptyState extends State<_RadarEmpty> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withOpacity(0.65);

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RadarPulse(controller: _c),
            const SizedBox(height: 18),
            Text('Listening for signals…', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Texts, alarms, app alerts — they’ll land here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.accessEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                  size: 18,
                  color: muted,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.checkingAccess
                      ? 'Checking notification access…'
                      : widget.accessEnabled
                          ? 'Notification access: ON'
                          : 'Notification access: OFF',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: widget.onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarPulse extends StatelessWidget {
  final Animation<double> controller;
  const _RadarPulse({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 140,
      height: 140,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = controller.value; // 0..1
          return CustomPaint(
            painter: _RadarPainter(
              t: t,
              color: theme.colorScheme.primary,
              ringColor: theme.colorScheme.primary.withOpacity(0.4),
            ),
          );
        },
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double t;
  final Color color;
  final Color ringColor;
  _RadarPainter({required this.t, required this.color, required this.ringColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide * 0.48;

    // Background subtle dot
    final dotPaint = Paint()..color = color.withOpacity(0.9);
    canvas.drawCircle(center, 3.5, dotPaint);

    // Expanding ring
    final r = (0.12 + 0.88 * t) * maxR;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = ringColor.withOpacity((1.0 - t).clamp(0.0, 1.0));
    canvas.drawCircle(center, r, ringPaint);

    // Sweep "beam" (simple arc)
    final beamAngle = (t * 6.283185307179586); // 2π
    final beamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.22);

    final rect = Rect.fromCircle(center: center, radius: maxR * 0.92);
    canvas.drawArc(rect, beamAngle - 0.4, 0.25, false, beamPaint);

    // Static guide rings
    final guide = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = ringColor.withOpacity(0.16);
    canvas.drawCircle(center, maxR * 0.35, guide);
    canvas.drawCircle(center, maxR * 0.65, guide);
    canvas.drawCircle(center, maxR * 0.92, guide);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.color != color || oldDelegate.ringColor != ringColor;
  }
}

String _fmtTime(DateTime d) {
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
