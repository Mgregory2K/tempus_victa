import 'package:flutter/material.dart';

import '../../core/signal_item.dart';
import '../../core/signal_mute_store.dart';
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
