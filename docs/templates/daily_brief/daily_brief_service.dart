import 'package:flutter/material.dart';

import '../../providers/db_provider.dart';
import '../../data/repos/actions_repo.dart';
import '../../services/telemetry/behavior_telemetry.dart';

class DailyBriefService {
  static const _kLastShownDate = 'daily_brief.last_shown_ymd';
  static const _kDeferUntilUtc = 'daily_brief.defer_until_utc';
  static const _kPreferredMinute = 'daily_brief.preferred_minute_of_day'; // learned

  static const int _defaultMorningCutoffMinute = 5 * 60; // 05:00 local

  static int _minuteOfDay(DateTime local) => local.hour * 60 + local.minute;

  static String _ymd(DateTime local) =>
      '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';

  static Future<void> maybeShowMorningBrief(BuildContext context) async {
    final nowLocal = DateTime.now();
    final ymd = _ymd(nowLocal);

    final last = (await DbProvider.db.getMeta(_kLastShownDate))?.trim();
    if (last == ymd) return;

    final deferUntil = await _getDeferUntilUtc();
    if (deferUntil != null && DateTime.now().toUtc().isBefore(deferUntil)) return;

    // If user has a learned preferred time, honor it loosely without nagging:
    final preferred = await _getPreferredMinute();
    final cutoff = preferred ?? _defaultMorningCutoffMinute;

    if (_minuteOfDay(nowLocal) < cutoff) {
      // Too early: do nothing. Next resume/open can trigger.
      return;
    }

    await showBriefNow(context, manual: false);
  }

  static Future<void> showBriefNow(BuildContext context, {required bool manual}) async {
    final actions = ActionsRepo();
    final now = DateTime.now();
    final ymd = _ymd(now);

    final open = await actions.list(includeDone: false, includeArchived: false);
    final doneAll = await actions.list(includeDone: true, includeArchived: false);

    final doneToday = doneAll.where((a) {
      final l = a.createdAt.toLocal();
      // “done” date isn’t stored; use a pragmatic fallback:
      // if marked done today, it will still be in list and we’ll treat created today as “today”.
      // This will get refined later when action status change timestamps are added.
      return _ymd(l) == ymd && a.status.name == 'done';
    }).toList();

    final dueToday = open.where((a) {
      final d = a.dueAt?.toLocal();
      if (d == null) return false;
      return _ymd(d) == ymd;
    }).toList();

    final carry = open.where((a) {
      final d = a.dueAt?.toLocal();
      if (d == null) return false;
      return d.isBefore(DateTime(now.year, now.month, now.day));
    }).toList();

    final t0 = DateTime.now();
    BehaviorTelemetry.log('daily_brief.open', {'manual': manual});

    final res = await showModalBottomSheet<_BriefAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _DailyBriefSheet(
        openCount: open.length,
        doneTodayCount: doneToday.length,
        dueToday: dueToday.map((a) => a.title).take(10).toList(),
        carryover: carry.map((a) => a.title).take(10).toList(),
      ),
    );

    final dwellMs = DateTime.now().difference(t0).inMilliseconds;
    BehaviorTelemetry.log('daily_brief.close', {'ms': dwellMs, 'action': res?.name});

    // Learn timing: if you keep it open longer, that time is “good”.
    await _learnPreferredTime(dwellMs);

    if (res == _BriefAction.defer30) {
      await _setDeferUntilUtc(DateTime.now().toUtc().add(const Duration(minutes: 30)));
      return;
    }

    // mark shown
    await DbProvider.db.setMeta(_kLastShownDate, ymd);
    await DbProvider.db.setMeta(_kDeferUntilUtc, '');
  }

  static Future<DateTime?> _getDeferUntilUtc() async {
    final s = (await DbProvider.db.getMeta(_kDeferUntilUtc))?.trim();
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static Future<void> _setDeferUntilUtc(DateTime utc) async {
    await DbProvider.db.setMeta(_kDeferUntilUtc, utc.toIso8601String());
  }

  static Future<int?> _getPreferredMinute() async {
    final s = (await DbProvider.db.getMeta(_kPreferredMinute))?.trim();
    final v = int.tryParse(s ?? '');
    if (v == null) return null;
    if (v < 0 || v > 1439) return null;
    return v;
  }

  static Future<void> _learnPreferredTime(int dwellMs) async {
    // Minimal RL-ish behavior:
    // If you dwell > 6s, we nudge preferred time toward now.
    // If you bail instantly (<2s), we nudge away from now (later refinement).
    final now = DateTime.now();
    final nowMin = _minuteOfDay(now);

    final prev = await _getPreferredMinute();
    if (prev == null) {
      if (dwellMs >= 6000) {
        await DbProvider.db.setMeta(_kPreferredMinute, nowMin.toString());
      }
      return;
    }

    int next = prev;
    if (dwellMs >= 6000) {
      // move 20% toward now
      next = (prev + ((nowMin - prev) * 0.2)).round();
    } else if (dwellMs <= 2000) {
      // move 10% away (push later)
      next = (prev + 18).clamp(0, 1439);
    }

    await DbProvider.db.setMeta(_kPreferredMinute, next.toString());
  }
}

enum _BriefAction { ok, defer30 }

class _DailyBriefSheet extends StatelessWidget {
  final int openCount;
  final int doneTodayCount;
  final List<String> dueToday;
  final List<String> carryover;

  const _DailyBriefSheet({
    required this.openCount,
    required this.doneTodayCount,
    required this.dueToday,
    required this.carryover,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      child: ListView(
        children: [
          Text('Daily Brief', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            'Short. Correct. Auditable.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 12),

          _section(context, 'Today', [
            'Open actions: $openCount',
            'Done today (approx): $doneTodayCount',
          ]),

          if (dueToday.isNotEmpty)
            _section(context, 'Due Today', dueToday.map((t) => '• $t').toList()),

          if (carryover.isNotEmpty)
            _section(context, 'Carryover', carryover.map((t) => '• $t').toList()),

          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(_BriefAction.defer30),
                  icon: const Icon(Icons.snooze_rounded),
                  label: const Text('Defer 30m'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(_BriefAction.ok),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('OK'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'It will learn the best time by when you actually read/use it. No nagging questions.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<String> lines) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (final l in lines) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(l)),
        ],
      ),
    );
  }
}
