import 'package:flutter/material.dart';

import '../../core/signal_item.dart';
import '../../core/signal_mute_store.dart';
import '../../core/doctrine/decision_audit_store.dart';
import '../../core/routing_rule_store.dart';
import '../theme/tempus_ui.dart';

class SignalDetailSheet extends StatefulWidget {
  final SignalItem item;
  final bool muted;
  final ValueChanged<bool> onAcknowledge;
  final ValueChanged<bool> onMuteChanged;
  const SignalDetailSheet({
    super.key,
    required this.item,
    required this.muted,
    required this.onAcknowledge,
    required this.onMuteChanged,
  });

  @override
  State<SignalDetailSheet> createState() => _SignalDetailSheetState();
}

class _SignalDetailSheetState extends State<SignalDetailSheet> {
  late bool _ack = widget.item.acknowledged;
  late bool _muted = widget.muted;
  DecisionAuditEntry? _audit;
  RouteTarget _ruleTarget = RouteTarget.none;

      Future<void> _loadRule() async {
    final r = await RoutingRuleStore().ruleForSource(widget.item.source);
    if (!mounted) return;
    setState(() => _ruleTarget = r?.target ?? RouteTarget.none);
  }

Future<void> _loadAudit() async {
    final entries = await DecisionAuditStore().load();
    final hit = entries.firstWhere(
      (e) => e.entityId == widget.item.id,
      orElse: () => DecisionAuditEntry(decisionId: '(none)', action: '(none)', confidence: 0.0, tsMs: 0),
    );
    if (!mounted) return;
    setState(() => _audit = hit.decisionId == '(none)' ? null : hit);
  }

  @override
  void initState() {
    super.initState();
    _loadAudit();
    _loadRule();
  }

@override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.item.title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cs.onSurface),
                ),
              ),
              TempusPill(text: widget.item.source),
            ],
          ),
          if ((widget.item.body ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(widget.item.body!, style: TextStyle(color: cs.onSurfaceVariant, height: 1.25)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              TempusPill(
                text: widget.item.count > 1 ? 'Seen ${widget.item.count}×' : 'Seen 1×',
              ),
              TempusPill(
                text: 'Last: ${_prettyTime(widget.item.lastSeenAt)}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _ack,
            onChanged: (v) {
              setState(() => _ack = v);
              widget.onAcknowledge(v);
            },
            title: const Text('Acknowledge'),
            subtitle: const Text('Keeps it logged, clears it from the inbox.'),
          ),
          SwitchListTile(
            value: _muted,
            onChanged: (v) async {
              setState(() => _muted = v);
              await SignalMuteStore.toggleMutedPackage(widget.item.source, v);
              widget.onMuteChanged(v);
            },
            title: const Text('Mute this app'),
            subtitle: const Text('Still logged. Stops appearing in the inbox.'),
          ),
          const SizedBox(height: 6),
          ExpansionTile(
            title: const Text('Routing Rule'),
            childrenPadding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('User override. If set, this wins over Twin+ learning.'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<RouteTarget>(
                initialValue: _ruleTarget,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Default route for this source',
                ),
                items: const [
                  DropdownMenuItem(value: RouteTarget.none, child: Text('No override')),
                  DropdownMenuItem(value: RouteTarget.tasks, child: Text('Always route to Tasks')),
                  DropdownMenuItem(value: RouteTarget.corkboard, child: Text('Always route to Corkboard')),
                  DropdownMenuItem(value: RouteTarget.recycle, child: Text('Always route to Recycle Bin')),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => _ruleTarget = v);
                  await RoutingRuleStore().setRule(widget.item.source, v);
                },
              ),
            ],
          ),

          ExpansionTile(
            title: const Text('Provenance'),
            childrenPadding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'signalId: ${widget.item.id}\nfingerprint: ${widget.item.fingerprint}\nlastDecisionId: ${_audit?.decisionId ?? '(none)'}\nlastAction: ${_audit?.action ?? '(none)'}\nconfidence: ${_audit == null ? '(n/a)' : _audit!.confidence.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _prettyTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
