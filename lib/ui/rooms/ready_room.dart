import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/metrics_store.dart';
import '../../core/ready_room_store.dart';
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

  List<ReadyRoomMessage> _msgs = [];

  bool _protocolActive = false;
  ProtocolConfig? _protocolConfig;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loaded = await ReadyRoomStore.load();
    final inferred = _inferProtocolState(loaded);
    if (!mounted) return;
    setState(() {
      _msgs = loaded;
      _protocolActive = inferred.active;
      _protocolConfig = inferred.config;
    });
    _jumpBottom();
  }

  _ProtocolState _inferProtocolState(List<ReadyRoomMessage> msgs) {
    // Protocol active if we have a start marker after the last end marker.
    int lastStart = -1;
    int lastEnd = -1;
    ProtocolConfig? cfg;

    for (int i = 0; i < msgs.length; i++) {
      final t = msgs[i].text;
      if (t.startsWith(ProtocolMarkers.start)) {
        lastStart = i;
        cfg = null;
      } else if (t.startsWith(ProtocolMarkers.end)) {
        lastEnd = i;
      } else if (t.startsWith(ProtocolMarkers.cfgPrefix)) {
        cfg = ProtocolConfig.tryParse(t);
      }
    }

    final active = lastStart != -1 && lastStart > lastEnd;
    return _ProtocolState(active: active, config: cfg);
  }

  Future<void> _append(String role, String text) async {
    final msg = ReadyRoomMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: role,
      text: text,
      createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    final next = [..._msgs, msg];
    setState(() => _msgs = next);
    await ReadyRoomStore.save(next);
  }

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Ready Room history?'),
        content: const Text('This deletes the local Ready Room feed on this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;

    await ReadyRoomStore.clear();
    if (!mounted) return;
    setState(() {
      _msgs = [];
      _protocolActive = false;
      _protocolConfig = null;
    });
  }

  Future<void> _exportFeed() async {
    final md = _buildExportMarkdown(_msgs);

    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/ready_room_export_$ts.md');
    await file.writeAsString(md);

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 12,
              bottom: 12 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Export created', style: TextStyle(fontWeight: FontWeight.w800))),
                    IconButton(
                      tooltip: 'Copy',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: md));
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      icon: const Icon(Icons.copy),
                    ),
                  ],
                ),
                Text('Saved to: ${file.path}', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: SingleChildScrollView(
                    child: SelectableText(md),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: md));
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    child: const Text('Copy to clipboard'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _buildExportMarkdown(List<ReadyRoomMessage> msgs) {
    final b = StringBuffer();
    b.writeln('# Ready Room Export');
    b.writeln('Generated: ${DateTime.now().toIso8601String()}');
    b.writeln();

    for (final m in msgs) {
      final t = DateTime.fromMillisecondsSinceEpoch(m.createdAtEpochMs).toIso8601String();

      if (m.text.startsWith(ProtocolMarkers.start)) {
        b.writeln('---');
        b.writeln('## READY ROOM PROTOCOL — START ($t)');
        b.writeln('---');
        b.writeln();
        continue;
      }
      if (m.text.startsWith(ProtocolMarkers.end)) {
        b.writeln();
        b.writeln('---');
        b.writeln('## READY ROOM PROTOCOL — END ($t)');
        b.writeln('---');
        b.writeln();
        continue;
      }
      if (m.text.startsWith(ProtocolMarkers.cfgPrefix)) {
        final cfg = ProtocolConfig.tryParse(m.text);
        if (cfg != null) {
          b.writeln('**Protocol Config:** intent=${cfg.intent}; issue=${cfg.issue}; figures=${cfg.figures.join(', ')}; surpriseEntrants=${cfg.allowSurpriseEntrants}');
          if (cfg.maxSentences != null) b.writeln('**Constraint:** maxSentences=${cfg.maxSentences}');
          if (cfg.maxChars != null) b.writeln('**Constraint:** maxChars=${cfg.maxChars}');
          if (cfg.noFollowUps) b.writeln('**Constraint:** noFollowUps=true');
          b.writeln();
        }
        continue;
      }

      final role = (m.role == 'assistant') ? 'Assistant' : (m.role == 'user') ? 'User' : 'System';
      b.writeln('**$role** ($t)');
      b.writeln();
      b.writeln(m.text.trim());
      b.writeln();
    }

    return b.toString();
  }

  Future<void> _invokeProtocol() async {
    if (_busy) return;
    final cfg = await showModalBottomSheet<ProtocolConfig>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _ProtocolInvokeSheet(),
    );
    if (cfg == null) return;

    await _append('system', ProtocolMarkers.start);
    await _append('system', cfg.toMarkerString());
    await _append('assistant', 'Moderator: Protocol invoked. Issue: "${cfg.issue}"');

    setState(() {
      _protocolActive = true;
      _protocolConfig = cfg;
    });
    _jumpBottom();
  }

  Future<void> _endProtocol() async {
    if (!_protocolActive) return;
    await _append('system', ProtocolMarkers.end);
    setState(() {
      _protocolActive = false;
      _protocolConfig = null;
    });
    _jumpBottom();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _busy) return;

    setState(() {
      _busy = true;
      _ctrl.clear();
    });

    await _append('user', text);

    try {
      final aiEnabled = await AiSettingsStore.isEnabled();
      final apiKey = await AiSettingsStore.getApiKey();
      String reply;

      if (_protocolActive) {
        reply = await _protocolRespond(
          input: text,
          aiEnabled: aiEnabled,
          apiKey: apiKey,
        );
      } else {
        reply = await _normalRespond(
          input: text,
          aiEnabled: aiEnabled,
          apiKey: apiKey,
        );
      }

      await _append('assistant', reply);
      _jumpBottom();
    } catch (_) {
      await _append('assistant', 'I couldn’t complete that request right now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _normalRespond({required String input, required bool aiEnabled, required String? apiKey}) async {
    if (aiEnabled && apiKey != null && apiKey.isNotEmpty) {
      final model = await AiSettingsStore.getModel() ?? 'gpt-4o-mini';
      final out = await OpenAiClient(apiKey: apiKey, model: model).respondText(input: input);
      await MetricsStore.inc(TvMetrics.aiCalls);
      return out.text;
    }

    await MetricsStore.inc(TvMetrics.webSearches);
    return _webFallback(input);
  }

  Future<String> _protocolRespond({required String input, required bool aiEnabled, required String? apiKey}) async {
    final cfg = _protocolConfig ?? ProtocolConfig.defaultConfig();

    if (aiEnabled && apiKey != null && apiKey.isNotEmpty) {
      final model = await AiSettingsStore.getModel() ?? 'gpt-4o-mini';
      final prompt = _buildProtocolPrompt(cfg, input);
      final out = await OpenAiClient(apiKey: apiKey, model: model).respondText(input: prompt);
      await MetricsStore.inc(TvMetrics.aiCalls);
      return out.text;
    }

    // No-AI fallback: still useful, still structured, still multi-turn.
    await MetricsStore.inc(TvMetrics.webSearches);
    return _protocolLocalFallback(cfg, input);
  }

  String _buildProtocolPrompt(ProtocolConfig cfg, String input) {
    // We can’t send structured system messages via the current OpenAiClient,
    // so we embed an instruction prefix into the single input.
    final b = StringBuffer();
    b.writeln('READY ROOM PROTOCOL (Active)');
    b.writeln('Intent: ${cfg.intent}');
    b.writeln('Figures: ${cfg.figures.join(', ')}');
    if (cfg.issue.trim().isNotEmpty) b.writeln('Issue: ${cfg.issue.trim()}');
    b.writeln('Rules: Multi-turn by default. Distinct voices. Moderated session.');
    b.writeln('Constraints: maxChars=${cfg.maxChars ?? 'none'}; maxSentences=${cfg.maxSentences ?? 'none'}; noFollowUps=${cfg.noFollowUps}');
    b.writeln('Surprise entrants allowed: ${cfg.allowSurpriseEntrants}');
    b.writeln();
    b.writeln('Write the response as:');
    b.writeln('Moderator: ...');
    for (final f in cfg.figures) {
      b.writeln('$f: ...');
    }
    b.writeln();
    b.writeln('User says: $input');

    return b.toString();
  }

  String _protocolLocalFallback(ProtocolConfig cfg, String input) {
    final figures = cfg.figures.isEmpty ? ['Socratic', 'Spock', 'Kirk'] : cfg.figures;
    final b = StringBuffer();

    b.writeln('Moderator: Protocol invoked (no AI). I can still run the structure and keep you moving.');
    b.writeln('Moderator: Your issue: "$input"');
    b.writeln();

    b.writeln('${figures[0]}: What outcome are we optimizing for, and what is the hidden cost if we get it wrong?');
    if (figures.length > 1) b.writeln('${figures[1]}: Define constraints and measurable success criteria. What evidence would change your mind?');
    if (figures.length > 2) b.writeln('${figures[2]}: What’s the smallest decisive action we can take today that keeps options open?');

    if (!cfg.noFollowUps) {
      b.writeln();
      b.writeln('Moderator: Answer those three prompts and I’ll run the next round.');
    }

    return b.toString();
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
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 220),
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
    return SafeArea(
      child: Column(
      children: [
        SizedBox(
          height: 52,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Text(
                _protocolActive ? 'Ready Room — Protocol Active' : 'Ready Room',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              if (!_protocolActive)
                IconButton(
                  tooltip: 'Invoke Protocol',
                  onPressed: _invokeProtocol,
                  icon: const Icon(Icons.rule_rounded),
                )
              else
                IconButton(
                  tooltip: 'End Protocol',
                  onPressed: _endProtocol,
                  icon: const Icon(Icons.stop_circle_outlined),
                ),
              IconButton(
                tooltip: 'Export',
                onPressed: _exportFeed,
                icon: const Icon(Icons.ios_share),
              ),
              IconButton(
                tooltip: 'Clear history',
                onPressed: _clearHistory,
                icon: const Icon(Icons.delete_outline),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            itemCount: _msgs.length,
            itemBuilder: (_, i) => _ReadyRoomRow(
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
                    hintText: _protocolActive ? 'Protocol input…' : 'Ask anything…',
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _busy ? null : _send,
                  icon: _busy
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    );
  }
}

class ProtocolMarkers {
  static const String start = '[[READY_ROOM_PROTOCOL_START]]';
  static const String end = '[[READY_ROOM_PROTOCOL_END]]';
  static const String cfgPrefix = '[[READY_ROOM_PROTOCOL_CFG]]';
}

class ProtocolConfig {
  final String intent;
  final List<String> figures;
  final String issue;
  final bool allowSurpriseEntrants;
  final int? maxChars;
  final int? maxSentences;
  final bool noFollowUps;

  const ProtocolConfig({
    required this.intent,
    required this.figures,
    required this.issue,
    required this.allowSurpriseEntrants,
    required this.maxChars,
    required this.maxSentences,
    required this.noFollowUps,
  });

  static ProtocolConfig defaultConfig() => const ProtocolConfig(
        intent: 'Decision support',
        figures: ['Socratic', 'Spock', 'Kirk'],
        issue: '',
        allowSurpriseEntrants: false,
        maxChars: null,
        maxSentences: null,
        noFollowUps: false,
      );

  String toMarkerString() {
    final j = jsonEncode({
      'intent': intent,
      'figures': figures,
      'issue': issue,
      'allowSurpriseEntrants': allowSurpriseEntrants,
      'maxChars': maxChars,
      'maxSentences': maxSentences,
      'noFollowUps': noFollowUps,
    });
    return '${ProtocolMarkers.cfgPrefix}$j';
  }

  static ProtocolConfig? tryParse(String markerText) {
    if (!markerText.startsWith(ProtocolMarkers.cfgPrefix)) return null;
    final raw = markerText.substring(ProtocolMarkers.cfgPrefix.length);
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final figures = (m['figures'] is List)
          ? (m['figures'] as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
          : <String>[];
      return ProtocolConfig(
        intent: (m['intent'] ?? 'Decision support').toString(),
        figures: figures,
        issue: (m['issue'] ?? '').toString(),
        allowSurpriseEntrants: (m['allowSurpriseEntrants'] == true),
        maxChars: (m['maxChars'] is int) ? m['maxChars'] as int : int.tryParse('${m['maxChars']}'),
        maxSentences: (m['maxSentences'] is int) ? m['maxSentences'] as int : int.tryParse('${m['maxSentences']}'),
        noFollowUps: (m['noFollowUps'] == true),
      );
    } catch (_) {
      return null;
    }
  }
}

class _ProtocolState {
  final bool active;
  final ProtocolConfig? config;
  const _ProtocolState({required this.active, required this.config});
}

class _ProtocolInvokeSheet extends StatefulWidget {
  const _ProtocolInvokeSheet();

  @override
  State<_ProtocolInvokeSheet> createState() => _ProtocolInvokeSheetState();
}

class _ProtocolInvokeSheetState extends State<_ProtocolInvokeSheet> {
  final _issueCtrl = TextEditingController();
  final _figuresCtrl = TextEditingController();
  String _intent = 'Decision support';
  bool _surprise = false;
  bool _noFollowUps = false;
  final _maxCharsCtrl = TextEditingController();
  final _maxSentCtrl = TextEditingController();

  @override
  void dispose() {
    _issueCtrl.dispose();
    _figuresCtrl.dispose();
    _maxCharsCtrl.dispose();
    _maxSentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 12,
          bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Invoke Ready Room Protocol', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _intent,
              decoration: const InputDecoration(labelText: 'Intent'),
              items: const [
                DropdownMenuItem(value: 'Decision support', child: Text('Decision support')),
                DropdownMenuItem(value: 'Debate and challenge', child: Text('Debate and challenge')),
                DropdownMenuItem(value: 'Learning or explanation', child: Text('Learning or explanation')),
                DropdownMenuItem(value: 'Scenario stress-testing', child: Text('Scenario stress-testing')),
                DropdownMenuItem(value: 'Entertainment', child: Text('Entertainment')),
              ],
              onChanged: (v) => setState(() => _intent = v ?? _intent),
            ),
            const SizedBox(height: 10),
            TvTextField(
              controller: _issueCtrl,
              hintText: 'Issue statement / what are we solving?',
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            TvTextField(
              controller: _figuresCtrl,
              hintText: 'Figures (comma-separated) e.g., Socratic, Spock, Kirk',
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _maxCharsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Max chars (optional)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _maxSentCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Max sentences (optional)'),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _surprise,
              onChanged: (v) => setState(() => _surprise = v),
              title: const Text('Allow surprise entrants'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _noFollowUps,
              onChanged: (v) => setState(() => _noFollowUps = v),
              title: const Text('No follow-up questions'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final issue = _issueCtrl.text.trim();
                  if (issue.isEmpty) return;
                  final figs = _figuresCtrl.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(growable: false);
                  final maxChars = int.tryParse(_maxCharsCtrl.text.trim());
                  final maxSent = int.tryParse(_maxSentCtrl.text.trim());

                  Navigator.of(context).pop(
                    ProtocolConfig(
                      intent: _intent,
                      figures: figs.isEmpty ? ['Socratic', 'Spock', 'Kirk'] : figs,
                      issue: issue,
                      allowSurpriseEntrants: _surprise,
                      maxChars: maxChars,
                      maxSentences: maxSent,
                      noFollowUps: _noFollowUps,
                    ),
                  );
                },
                child: const Text('Begin Protocol'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ReadyRoomRow extends StatelessWidget {
  final ReadyRoomMessage msg;
  final Future<void> Function(String url) onTapUrl;

  const _ReadyRoomRow({required this.msg, required this.onTapUrl});

  static final _urlRe = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);

  @override
  Widget build(BuildContext context) {
    if (msg.text.startsWith(ProtocolMarkers.start)) {
      return _marker(context, 'READY ROOM PROTOCOL — START');
    }
    if (msg.text.startsWith(ProtocolMarkers.end)) {
      return _marker(context, 'READY ROOM PROTOCOL — END');
    }
    if (msg.text.startsWith(ProtocolMarkers.cfgPrefix)) {
      // Hide the raw config marker from the feed; it still exports.
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isUser = msg.role == 'user';
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

  Widget _marker(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: cs.outlineVariant.withOpacity(.7))),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: cs.outlineVariant.withOpacity(.7))),
        ],
      ),
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
