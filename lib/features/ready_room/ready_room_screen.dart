// Tempus Vista rebuild - generated 2026-02-21
// Local-first, Android-first.


import 'package:flutter/material.dart';

import '../../data/repositories/signal_repo.dart';
import '../../services/logging/jsonl_logger.dart';
import '../../ui/tempus_scaffold.dart';
import '../../ui/widgets/glass_card.dart';
import '../../widgets/input_composer.dart';

class ReadyRoomScreen extends StatefulWidget {
  final void Function(int index)? onNavigate;
  final int? selectedIndex;

  const ReadyRoomScreen({super.key, this.onNavigate, this.selectedIndex});

  @override
  State<ReadyRoomScreen> createState() => _ReadyRoomScreenState();
}

class _ReadyRoomScreenState extends State<ReadyRoomScreen> {
  final List<_Line> _lines = [];

  Future<void> _send({String? text, String? transcript}) async {
    final nowUtc = DateTime.now().toUtc();
    final msg = (text ?? transcript ?? '').trim();
    if (msg.isEmpty) return;

    setState(() => _lines.insert(0, _Line(msg, nowUtc)));

    // Store as a Signal for unified ingestion.
    final s = await SignalRepo.instance.create(
      kind: transcript != null ? 'voice' : 'text',
      source: transcript != null ? 'ready_room_voice' : 'ready_room_text',
      text: text,
      transcript: transcript,
      capturedAtUtc: nowUtc,
    );

    await JsonlLogger.instance.append('ready_room.jsonl', {
      'event': 'ready_room_line',
      'signalId': s.id,
      'atUtc': nowUtc.toIso8601String(),
      'text': text,
      'transcript': transcript,
    });
  }

  @override
  Widget build(BuildContext context) {
    return TempusScaffold(
      title: 'Ready Room',
      selectedIndex: widget.selectedIndex ?? 5,
      onNavigate: widget.onNavigate ?? (_) {},
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            GlassCard(
              child: InputComposer(
                hint: 'Ask / think out loud… (saved locally)',
                onSubmit: ({text, transcript}) => _send(text: text, transcript: transcript),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                reverse: true,
                itemCount: _lines.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final l = _lines[i];
                  return GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.text),
                        const SizedBox(height: 6),
                        Text('UTC: ${l.atUtc.toIso8601String()}', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line {
  final String text;
  final DateTime atUtc;
  _Line(this.text, this.atUtc);
}
