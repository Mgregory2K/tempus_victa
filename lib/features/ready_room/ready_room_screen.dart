import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/repositories/signal_repo.dart';
import '../../services/logging/jsonl_logger.dart';
import '../../services/ready_room/ready_room_router.dart';
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
  bool _busy = false;

  Future<void> _send({String? text, String? transcript}) async {
    final nowUtc = DateTime.now().toUtc();
    final msg = (text ?? transcript ?? '').trim();
    if (msg.isEmpty) return;

    setState(() {
      _busy = true;
      _lines.insert(0, _Line('You: $msg', nowUtc));
    });

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

    // Route through local→trusted→web→AI.
    final result = await ReadyRoomRouter.route(msg);
    if (!mounted) return;

    setState(() {
      _busy = false;
      _lines.insert(
        0,
        _Line('${result.title}\n\n${result.body}', DateTime.now().toUtc(), links: result.links),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return TempusScaffold(
      title: 'Ready Room',
      selectedIndex: widget.selectedIndex ?? 8,
      onNavigate: widget.onNavigate ?? (_) {},
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            GlassCard(
              child: InputComposer(
                hint: 'Ask / think out loud… (local→trusted→web→AI)',
                enabled: !_busy,
                onSubmit: ({text, transcript}) => _send(text: text, transcript: transcript),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future<void>.delayed(const Duration(milliseconds: 300));
                  if (mounted) setState(() {});
                },
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
                          if (l.links.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: l.links.map((lnk) {
                                return ActionChip(
                                  label: Text(lnk.title, overflow: TextOverflow.ellipsis),
                                  onPressed: () async {
                                    final uri = Uri.tryParse(lnk.url);
                                    if (uri == null) return;
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text('UTC: ${l.atUtc.toIso8601String()}', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    );
                  },
                ),
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
  final List<ReadyRoomLink> links;
  _Line(this.text, this.atUtc, {this.links = const []});
}
