import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/metrics_store.dart';
import '../../services/ai/ai_settings_store.dart';
import '../../services/ai/openai_client.dart';
import '../theme/tv_textfield.dart';

class ReadyRoom extends StatefulWidget {
  final String? roomName;
  const ReadyRoom({super.key, this.roomName});

  @override
  State<ReadyRoom> createState() => _ReadyRoomState();
}

class _ReadyRoomState extends State<ReadyRoom> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;

  final List<_Msg> _msgs = [];

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _busy) return;

    setState(() {
      _msgs.add(_Msg(user: true, text: text));
      _busy = true;
      _ctrl.clear();
    });

    try {
      final aiEnabled = await AiSettingsStore.isEnabled();
      final apiKey = await AiSettingsStore.getApiKey();
      String reply;

      if (aiEnabled && apiKey != null && apiKey.isNotEmpty) {
        final model = await AiSettingsStore.getModel() ?? 'gpt-4o-mini';
        reply = (await OpenAiClient(apiKey: apiKey, model: model).respondText(input: text)).text;
        await MetricsStore.inc(TvMetrics.aiCalls);
      } else {
        reply = _webFallback(text);
        await MetricsStore.inc(TvMetrics.webSearches);
      }

      setState(() {
        _msgs.add(_Msg(user: false, text: reply));
      });
      _jumpBottom();
    } catch (_) {
      setState(() {
        _msgs.add(const _Msg(user: false, text: 'I couldn’t complete that request right now.'));
      });
    } finally {
      setState(() => _busy = false);
    }
  }

  String _webFallback(String q) {
    final enc = Uri.encodeComponent(q);
    final ddg = 'https://duckduckgo.com/?q=$enc';
    final google = 'https://www.google.com/search?q=$enc';
    return 'Here are some results you can open:\n\n• $ddg\n• $google';
  }

  void _jumpBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openUrl(String url) async {
    final u = Uri.tryParse(url);
    if (u == null) return;
    await launchUrl(u, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            itemCount: _msgs.length,
            itemBuilder: (_, i) => _MsgBubble(
              msg: _msgs[i],
              onTapUrl: _openUrl,
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TvTextField(
                    controller: _ctrl,
                    hintText: 'Ask anything…',
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _busy ? null : _send,
                  icon: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Msg {
  final bool user;
  final String text;
  const _Msg({required this.user, required this.text});
}

class _MsgBubble extends StatelessWidget {
  final _Msg msg;
  final Future<void> Function(String url) onTapUrl;

  const _MsgBubble({required this.msg, required this.onTapUrl});

  static final _urlRe = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = msg.user;
    final bg = isUser ? theme.colorScheme.primary.withOpacity(0.12) : theme.cardColor;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: align,
      children: [
        Card(
          color: bg,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _buildRich(context, msg.text),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildRich(BuildContext context, String text) {
    final spans = <InlineSpan>[];
    int idx = 0;
    for (final m in _urlRe.allMatches(text)) {
      if (m.start > idx) {
        spans.add(TextSpan(text: text.substring(idx, m.start)));
      }
      final url = text.substring(m.start, m.end);
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => onTapUrl(url),
            child: Text(
              url,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      );
      idx = m.end;
    }
    if (idx < text.length) spans.add(TextSpan(text: text.substring(idx)));
    return RichText(text: TextSpan(style: Theme.of(context).textTheme.bodyMedium, children: spans));
  }
}
