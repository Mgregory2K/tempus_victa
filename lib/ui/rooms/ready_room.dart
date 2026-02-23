import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ready_room_store.dart';
import '../../core/metrics_store.dart';
import '../../services/ai/ai_settings_store.dart';
import '../../services/ai/openai_client.dart';
import '../../services/web/web_search_client.dart';
import '../room_frame.dart';

class ReadyRoom extends StatefulWidget {
  final String roomName;
  const ReadyRoom({super.key, required this.roomName});

  @override
  State<ReadyRoom> createState() => _ReadyRoomState();
}

class _ReadyRoomState extends State<ReadyRoom> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _loading = true;
  bool _sending = false;
  List<ReadyRoomMessage> _messages = <ReadyRoomMessage>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final msgs = await ReadyRoomStore.load();
    if (!mounted) return;
    setState(() {
      _messages = msgs;
      _loading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _clear() async {
    await ReadyRoomStore.clear();
    if (!mounted) return;
    setState(() => _messages = <ReadyRoomMessage>[]);
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    _inputCtrl.clear();

    final userMsg = ReadyRoomMessage(
      id: const Uuid().v4(),
      role: 'user',
      text: text,
      createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );

    setState(() {
      _sending = true;
      _messages = [..._messages, userMsg];
    });
    await ReadyRoomStore.append(userMsg);
    _scrollToBottom();

    // AI is optional. If disabled/unconfigured, respond locally (and clearly).
    final aiEnabled = await AiSettingsStore.isEnabled();
    final apiKey = await AiSettingsStore.getApiKey();
    final model = await AiSettingsStore.getModel();

    String reply;
    if (!aiEnabled || apiKey == null || apiKey.isEmpty) {
      // Internet layer MUST work even when AI is off.
      await MetricsStore.inc(TvMetrics.webSearches);
      final web = WebSearchClient();
      final webResp = await web.search(text, maxLinks: 5);

      final q = Uri.encodeQueryComponent(text);
      final ddgUrl = 'https://duckduckgo.com/?q=$q';
      final googleUrl = 'https://www.google.com/search?q=$q';

      final lines = <String>[];
      if (webResp.ok) {
        if ((webResp.abstractText ?? '').isNotEmpty) {
          lines.add(webResp.abstractText!.trim());
        }
        if (webResp.links.isNotEmpty) {
          if (lines.isNotEmpty) lines.add('');
          for (final l in webResp.links) {
            lines.add('• ${l.titleOrSnippet}\n${l.url}');
          }
        }
        if (lines.isEmpty) {
          lines.add('No quick results found. Try rephrasing or making the query more specific.');
        }
      } else {
        lines.add('No quick results found. Try rephrasing or making the query more specific.');
      }

      lines.add('');
      lines.add('More results:');
      lines.add(ddgUrl);
      lines.add(googleUrl);

      reply = lines.join('\n');
    } else {
      // Keep instructions minimal and aligned to the handoff philosophy.
      final instructions = [
        'You are Tempus Victa (local-first).',
        'AI is opt-in augmentation; never imply the app cannot function without AI.',
        'Prefer concise, actionable answers.',
        'If the user asks for implementation steps, provide short checklists.',
      ].join('\n');

      final client = OpenAiClient(apiKey: apiKey, model: model);
      await MetricsStore.inc(TvMetrics.aiCalls);
      final resp = await client.respondText(
        input: text,
        instructions: instructions,
        maxOutputTokens: 700,
      );
      reply = resp.ok ? resp.text : (resp.error ?? 'AI request failed');
    }

    final assistantMsg = ReadyRoomMessage(
      id: const Uuid().v4(),
      role: 'assistant',
      text: reply,
      createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    await ReadyRoomStore.append(assistantMsg);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _messages = [..._messages, assistantMsg];
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return RoomFrame(
        title: widget.roomName,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return RoomFrame(
      title: widget.roomName,
      child: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _emptyState(context)
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) => _bubble(context, _messages[i]),
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Clear',
                  onPressed: _messages.isEmpty ? null : _clear,
                  icon: const Icon(Icons.delete_sweep_rounded),
                ),
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Ask Tempus…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _sending ? null : _send,
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.meeting_room_rounded, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'Ready Room',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask anything. If needed, it will pull from the web and return links you can tap.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(BuildContext context, ReadyRoomMessage m) {
    final isUser = m.role == 'user';
    final bg = isUser
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceVariant;
    final fg = isUser
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: _linkified(m.text, TextStyle(color: fg, height: 1.25)),
      ),
    );
  }

  Widget _linkified(String text, TextStyle style) {
    // Simple URL detection. Keeps UX “magic”: user just sees clickable links.
    final urlRe = RegExp(r'(https?:\/\/[^\s]+)');
    final matches = urlRe.allMatches(text).toList(growable: false);
    if (matches.isEmpty) {
      return SelectableText(text, style: style);
    }

    final spans = <TextSpan>[];
    int last = 0;
    for (final m in matches) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final url = text.substring(m.start, m.end);
      spans.add(
        TextSpan(
          text: url,
          style: style.copyWith(decoration: TextDecoration.underline, fontWeight: FontWeight.w600),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
        ),
      );
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }

    return SelectableText.rich(TextSpan(style: style, children: spans));
  }
}
