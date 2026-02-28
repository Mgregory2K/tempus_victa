import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/metrics_store.dart';
import '../../core/ready_room_store.dart';
import '../../core/sources_of_truth_store.dart';
import '../../core/twin_plus/router.dart';
import '../../core/twin_plus/twin_plus_scope.dart';
import '../../core/twin_plus/twin_event.dart';
import '../../services/ai/ai_settings_store.dart';
import '../../services/ai/openai_client.dart';
import '../../services/web/web_search_client.dart';
import '../../core/doctrine/doctrine_engine.dart';
import '../../core/doctrine/doctrine_models.dart';
import '../theme/tv_textfield.dart';
import '../../core/app_settings_store.dart';
import '../widgets/dev_trace_panel.dart';

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
  String? _lastDecisionId;

  bool _devMode = false;
  List<String> _devTrace = const [];

  List<ReadyRoomMessage> _msgs = [];

  bool _protocolActive = false;
  ProtocolConfig? _protocolConfig;

  // ===========================
  // ADD: prompt history (↑ / ↓)
  // ===========================
  final List<String> _promptHistory = <String>[];
  int _promptHistoryIndex = -1;

  void _historyUp() {
    if (_promptHistory.isEmpty) return;

    // Only recall when caret is at the start (so arrow-up still works in multiline editing).
    final sel = _ctrl.selection;
    final caretAtStart = sel.isValid && sel.baseOffset <= 0 && sel.extentOffset <= 0;
    if (!caretAtStart) return;

    if (_promptHistoryIndex == -1) {
      _promptHistoryIndex = _promptHistory.length; // one past end
    }
    if (_promptHistoryIndex > 0) _promptHistoryIndex--;

    final v = _promptHistory[_promptHistoryIndex];
    _ctrl.value = TextEditingValue(
      text: v,
      selection: TextSelection.collapsed(offset: v.length),
      composing: TextRange.empty,
    );
  }

  void _historyDown() {
    if (_promptHistory.isEmpty) return;

    final sel = _ctrl.selection;
    final caretAtEnd = sel.isValid && sel.baseOffset >= _ctrl.text.length && sel.extentOffset >= _ctrl.text.length;
    if (!caretAtEnd) return;

    if (_promptHistoryIndex == -1) return;

    if (_promptHistoryIndex < _promptHistory.length - 1) {
      _promptHistoryIndex++;
      final v = _promptHistory[_promptHistoryIndex];
      _ctrl.value = TextEditingValue(
        text: v,
        selection: TextSelection.collapsed(offset: v.length),
        composing: TextRange.empty,
      );
    } else {
      _promptHistoryIndex = -1;
      _ctrl.clear();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDevMode();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadDevMode() async {
    final v = await AppSettingsStore().loadDevMode();
    if (!mounted) return;
    setState(() => _devMode = v);
  }

  Future<void> _toggleDevMode() async {
    final next = await AppSettingsStore().toggleDevMode();
    if (!mounted) return;
    setState(() => _devMode = next);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(next ? 'Dev Mode enabled' : 'Dev Mode disabled')),
    );
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

    // ADD: clear prompt history (session)
    _promptHistory.clear();
    _promptHistoryIndex = -1;
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
          b.writeln(
              '**Protocol Config:** intent=${cfg.intent}; issue=${cfg.issue}; figures=${cfg.figures.join(', ')}; surpriseEntrants=${cfg.allowSurpriseEntrants}');
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

    // ===========================
    // ADD: remember prompt
    // ===========================
    _promptHistory.add(text);
    _promptHistoryIndex = -1;

    await _append('user', text);

    final kernel = TwinPlusScope.of(context);

    try {
      final aiEnabled = await AiSettingsStore.isEnabled();
      final apiKey = await AiSettingsStore.getApiKey();

      // Sync Twin+ fast preference mirror (routing must respect opt-in)
      await kernel.prefs.setAiOptIn(aiEnabled && apiKey != null && apiKey.trim().isNotEmpty);

      final justFactsSignal = text.toLowerCase().startsWith('just the facts');
      // Runtime signal for this interaction (does not require AI)
      if (justFactsSignal) {
        await kernel.prefs.setJustTheFacts(true);
      }

      // Build recent context for routing & follow-up heuristics.
      final recentUserTurns = _msgs
          .where((m) => m.role == 'user')
          .map((m) => m.text)
          .toList();

      final sig = IntentSignals.analyze(text, recentUserTurns: recentUserTurns);

      // Canonical routing/execution: Local → Trusted → Web → AI (opt-in)
      final result = await DoctrineEngine.instance.execute(
        DoctrineRequest(
          surface: 'ready_room',
          inputText: text,
          recentUserTurns: recentUserTurns,
          timeHorizon: 'today',
          needsVerifiableFacts: sig.needsVerifiableFacts,
          taskType: sig.taskType,
          devMode: _devMode,
        ),
      );

      _lastDecisionId = result.decisionId;

      if (_devMode) {
        setState(() {
          _devTrace = result.debugTrace;
        });
      }

      var out = result.text.trim();

      // Append curated sources (no engine branding).
      if (result.webResults.isNotEmpty) {
        final b = StringBuffer();
        b.writeln(out);
        b.writeln();
        b.writeln('Sources:');
        for (final r in result.webResults) {
          b.writeln('- ${r.title}');
          b.writeln('  ${r.url}');
        }
        out = b.toString().trim();
      } else if (result.fallbackLinks.isNotEmpty) {
        final b = StringBuffer();
        b.writeln(out);
        b.writeln();
        b.writeln('Links:');
        for (final u in result.fallbackLinks) {
          b.writeln('- $u');
        }
        out = b.toString().trim();
      }

      await _append('system', out);
} catch (e) {
      await _append('assistant', 'Error: $e');
    } finally {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  // ===========================
  // ADD: multi-turn context + freshness
  // ===========================
  String _buildAiContextPrompt({
    required String userInput,
    String? modeLabel,
  }) {
    final nowYear = DateTime.now().year;

    final b = StringBuffer();
    b.writeln('FRESHNESS RULE: If you reference “latest/current/recent/last” events, assume the current year is $nowYear unless the user explicitly provides a date/year.');
    b.writeln('FOLLOW-UP RULE: Treat the user’s message as a continuation of this conversation unless the user explicitly starts a new topic.');
    if (modeLabel != null && modeLabel.trim().isNotEmpty) {
      b.writeln('MODE: $modeLabel');
    }
    b.writeln();
    b.writeln('CONVERSATION CONTEXT (most recent last):');

    // Keep last N messages; skip raw protocol config markers to avoid poisoning context.
    const int maxMsgs = 14;
    final recent = _msgs.length > maxMsgs ? _msgs.sublist(_msgs.length - maxMsgs) : _msgs;

    for (final m in recent) {
      final t = m.text;
      if (t.startsWith(ProtocolMarkers.cfgPrefix)) continue;
      if (t.startsWith(ProtocolMarkers.start)) {
        b.writeln('SYSTEM: [READY ROOM PROTOCOL START]');
        continue;
      }
      if (t.startsWith(ProtocolMarkers.end)) {
        b.writeln('SYSTEM: [READY ROOM PROTOCOL END]');
        continue;
      }
      final role = (m.role == 'assistant') ? 'ASSISTANT' : (m.role == 'user') ? 'USER' : 'SYSTEM';
      b.writeln('$role: ${m.text}');
    }

    b.writeln();
    b.writeln('USER: $userInput');

    return b.toString();
  }

  Future<String> _normalRespond({
    required String input,
    required bool aiEnabled,
    required String? apiKey,
    int maxOutputTokens = 600,
    required bool webFirst,
    required bool llmAllowedByPlan,
  }) async {
    _WebBundle? web;
    if (webFirst) {
      web = await _fetchWeb(input);
      await MetricsStore.inc(TvMetrics.webSearches);
    }

    final canLlm = aiEnabled && llmAllowedByPlan && apiKey != null && apiKey.isNotEmpty;
    if (canLlm) {
      final model = await AiSettingsStore.getModel() ?? 'gpt-4o-mini';
      final stitched = _buildAiContextPrompt(userInput: input, modeLabel: 'Normal');

      final prompt = (web == null)
          ? stitched
          : _joinBlocks([
              stitched,
              'WEB RESULTS (use these for anything time-sensitive; include a couple of source links at the end):',
              web.forPrompt,
            ]);

      final out = await OpenAiClient(apiKey: apiKey, model: model).respondText(
        input: prompt,
        maxOutputTokens: maxOutputTokens,
      );
      await MetricsStore.inc(TvMetrics.aiCalls);
      return out.text;
    }

    // No-AI path.
    if (web != null) return web.forUser;
    await MetricsStore.inc(TvMetrics.webSearches);
    final w = await _fetchWeb(input);
    return w.forUser;
  }

  Future<String> _protocolRespond({
    required String input,
    required bool aiEnabled,
    required String? apiKey,
    int maxOutputTokens = 600,
    required bool webFirst,
    required bool llmAllowedByPlan,
  }) async {
    final cfg = _protocolConfig ?? ProtocolConfig.defaultConfig();

    _WebBundle? web;
    if (webFirst) {
      web = await _fetchWeb(input);
      await MetricsStore.inc(TvMetrics.webSearches);
    }

    final canLlm = aiEnabled && llmAllowedByPlan && apiKey != null && apiKey.isNotEmpty;
    if (canLlm) {
      final model = await AiSettingsStore.getModel() ?? 'gpt-4o-mini';

      final protocolPrompt = _buildProtocolPrompt(cfg, input);
      final stitched = _buildAiContextPrompt(userInput: protocolPrompt, modeLabel: 'Protocol');

      final prompt = (web == null)
          ? stitched
          : _joinBlocks([
              stitched,
              'WEB RESULTS (use these for any time-sensitive claims; include a couple of links at the end):',
              web.forPrompt,
            ]);

      final out = await OpenAiClient(apiKey: apiKey, model: model).respondText(
        input: prompt,
        maxOutputTokens: maxOutputTokens,
      );
      await MetricsStore.inc(TvMetrics.aiCalls);
      return out.text;
    }

    // No-AI fallback: still useful, still structured, still multi-turn.
    if (web != null) {
      return _joinBlocks([
        _protocolLocalFallback(cfg, input),
        '',
        'Web results you can open:',
        web.forUser,
      ]);
    }
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

  static String _joinBlocks(List<String> blocks) {
    final b = StringBuffer();
    for (final s in blocks) {
      if (s.trim().isEmpty) {
        b.writeln();
      } else {
        b.writeln(s.trimRight());
        b.writeln();
      }
    }
    return b.toString().trimRight();
  }

  Future<_WebBundle> _fetchWeb(String query) async {
    try {
      final res = await WebSearchClient().search(query, maxLinks: 5);
      final trusted = await SourcesOfTruthStore.trustedDomains(minTrust: 0.75);
      // Update usage counters for surfaced domains.
      for (final r in res.links) {
        final d = _domainFromUrl(r.url);
        if (d.isNotEmpty) {
          await SourcesOfTruthStore.markDomainUsed(d);
        }
      }
      return _formatWeb(res, trustedDomains: trusted);
    } catch (_) {
      return _WebBundle(forUser: _webFallback(query), forPrompt: _webFallback(query));
    }
  }

  _WebBundle _formatWeb(WebSearchResponse res, {required Set<String> trustedDomains}) {
    final user = StringBuffer();
    final prompt = StringBuffer();

    if ((res.abstractText ?? '').trim().isNotEmpty) {
      user.writeln(res.abstractText!.trim());
      user.writeln();
      prompt.writeln('Abstract: ${res.abstractText!.trim()}');
    }

    if (res.links.isEmpty) {
      user.writeln('No web results returned.');
      return _WebBundle(forUser: user.toString().trimRight(), forPrompt: prompt.toString().trimRight());
    }

    user.writeln('Top web results:');
    prompt.writeln('Top results:');

    for (final r in res.links) {
      final d = _domainFromUrl(r.url);
      final tag = trustedDomains.contains(d) ? ' (trusted)' : '';
      user.writeln('• ${r.titleOrSnippet}$tag');
      user.writeln('  ${r.url}');

      prompt.writeln('- ${r.titleOrSnippet}$tag | ${r.url}');
    }

    return _WebBundle(forUser: user.toString().trimRight(), forPrompt: prompt.toString().trimRight());
  }

  static String _domainFromUrl(String url) {
    final u = Uri.tryParse(url);
    if (u == null) return '';
    var h = u.host.toLowerCase();
    if (h.startsWith('www.')) h = h.substring(4);
    return h;
  }

  String _webFallback(String q) {
    final enc = Uri.encodeComponent(q);
    final ddg = 'https://duckduckgo.com/?q=$enc';
    final google = 'https://www.google.com/search?q=$enc';
    return 'Here are some results you can open:\n\n• $ddg\n• $google';
  }

  Future<void> _feedback(String kind) async {
    final kernel = TwinPlusScope.of(context);
    kernel.observe(TwinEvent.feedbackGiven(surface: 'ready_room', feedback: kind, decisionId: _lastDecisionId));

    // Reinforcement updates (local, deterministic)
    final k = kind.toLowerCase();
    if (k.contains('too long')) {
      await kernel.prefs.reinforceVerboseComplaint();
    } else if (k.contains('wrong source') || k.contains('stale')) {
      await kernel.prefs.reinforceStaleComplaint();
    } else if (k.contains('stop asking')) {
      await kernel.prefs.reinforceClarificationComplaint();
    } else if (k.contains('just the facts')) {
      // Treat as a runtime signal; we keep it on until user turns it off.
      await kernel.prefs.setJustTheFacts(true);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Twin+ noted: $kind'), duration: const Duration(milliseconds: 850)),
    );
  }

  Future<void> _toggleJustFactsOff() async {
    final kernel = TwinPlusScope.of(context);
    await kernel.prefs.setJustTheFacts(false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Just the facts… OFF'), duration: Duration(milliseconds: 850)),
    );
  }

  Future<void> _openLegacyFeedbackSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 2),
                  child: Text('Twin+ quick feedback', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                ),
                ActionChip(label: const Text('Too long'), onPressed: () => _feedback('Too long')),
                ActionChip(label: const Text('Wrong source / stale'), onPressed: () => _feedback('Wrong source / stale')),
                ActionChip(label: const Text('Stop asking questions'), onPressed: () => _feedback('Stop asking questions')),
                ActionChip(label: const Text('Just the facts… ON'), onPressed: () => _feedback('Just the facts')),
                ActionChip(label: const Text('Just the facts… OFF'), onPressed: _toggleJustFactsOff),
              ],
            ),
          ),
        );
      },
    );
  }

  
  Future<void> _setVote(String msgId, int? vote) async {
    final idx = _msgs.indexWhere((m) => m.id == msgId);
    if (idx == -1) return;
    final cur = _msgs[idx];

    // Only allow voting on assistant messages (ignore otherwise).
    if (cur.role != 'assistant') return;

    // Normalize vote
    final nextVote = (vote == null) ? null : (vote > 0 ? 1 : -1);

    final updated = cur.copyWith(vote: nextVote);
    final next = [..._msgs];
    next[idx] = updated;

    setState(() => _msgs = next);
    await ReadyRoomStore.save(next);

    // Emit explicit feedback to Twin+ (local-only)
    final kernel = TwinPlusScope.of(context);
    kernel.observe(
      TwinEvent.feedbackGiven(
        surface: 'ready_room',
        feedback: nextVote == 1 ? 'upvote' : nextVote == -1 ? 'downvote' : 'vote_cleared',
        decisionId: _lastDecisionId,
        responseId: msgId,
      ),
    );

    // During early learning, collect a subtle "why" when a downvote is given.
    if (nextVote == -1) {
      await _maybeCollectDownvoteDetails(msgId: msgId);
    }
  }

  Future<void> _maybeCollectDownvoteDetails({required String msgId}) async {
    if (!mounted) return;

    final kernel = TwinPlusScope.of(context);
    final threshold = kernel.prefs.downvoteDetailThreshold;
    final count = kernel.prefs.downvoteDetailCount;
    if (threshold <= 0) return;
    if (count >= threshold) return;

    // We count showing the prompt (not the selection) so it naturally phases out.
    await kernel.prefs.incDownvoteDetailCount();

    final res = await showModalBottomSheet<_DownvoteDetailsResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => const _DownvoteDetailsSheet(),
    );
    if (res == null) return;

    final reason = res.reason.trim();
    final details = res.details.trim();
    final clipped = details.length > 140 ? details.substring(0, 140) : details;
    final summary = clipped.isEmpty ? reason : '$reason — $clipped';

    kernel.observe(
      TwinEvent.feedbackGiven(
        surface: 'ready_room',
        feedback: 'downvote_details:$summary',
        decisionId: _lastDecisionId,
        responseId: msgId,
      ),
    );

    // Reinforcement updates (local, deterministic)
    final k = reason.toLowerCase();
    if (k.contains('too long')) {
      await kernel.prefs.reinforceVerboseComplaint();
    } else if (k.contains('wrong source') || k.contains('stale')) {
      await kernel.prefs.reinforceStaleComplaint();
    } else if (k.contains('stop asking')) {
      await kernel.prefs.reinforceClarificationComplaint();
    }
  }

  Future<void> _toggleWrongSource(String msgId) async {
    final idx = _msgs.indexWhere((m) => m.id == msgId);
    if (idx == -1) return;
    final cur = _msgs[idx];

    if (cur.role != 'assistant') return;

    final updated = cur.copyWith(wrongSource: !cur.wrongSource);
    final next = [..._msgs];
    next[idx] = updated;

    setState(() => _msgs = next);
    await ReadyRoomStore.save(next);

    final kernel = TwinPlusScope.of(context);
    kernel.observe(
      TwinEvent.feedbackGiven(
        surface: 'ready_room',
        feedback: updated.wrongSource ? 'wrong_source' : 'wrong_source_cleared',
        decisionId: _lastDecisionId,
      ),
    );
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
                GestureDetector(
                  onLongPress: _toggleDevMode,
                  child: Text(
                    _protocolActive ? 'Ready Room — Protocol Active' : 'Ready Room',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
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
                tooltip: 'Feedback',
                onPressed: _openLegacyFeedbackSheet,
                icon: const Icon(Icons.feedback_outlined),
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
          if (_devMode) DevTracePanel(lines: _devTrace),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _msgs.length,
              itemBuilder: (_, i) => _ReadyRoomRow(
                msg: _msgs[i],
                onTapUrl: _openUrl,
                onVote: (v) => _setVote(_msgs[i].id, v),
                onToggleWrongSource: () => _toggleWrongSource(_msgs[i].id),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CallbackShortcuts(
                          bindings: <ShortcutActivator, VoidCallback>{
                            const SingleActivator(LogicalKeyboardKey.arrowUp): _historyUp,
                            const SingleActivator(LogicalKeyboardKey.arrowDown): _historyDown,
                          },
                          child: TvTextField(
                            controller: _ctrl,
                            hintText: _protocolActive ? 'Protocol input…' : 'Ask anything…',
                            onSubmitted: (_) => _send(),
                            twinSurface: 'ready_room',
                            twinFieldId: 'input',
                          ),
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
                const SizedBox(height: 8),
                if (kDebugMode)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tip: Use the Feedback icon for quick tags (debug only).',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
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
              initialValue: _intent,
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

  /// Per-assistant-message explicit feedback.
  /// vote: 1=up, -1=down, null=clear
  final void Function(int? vote) onVote;
  final VoidCallback onToggleWrongSource;

  const _ReadyRoomRow({
    required this.msg,
    required this.onTapUrl,
    required this.onVote,
    required this.onToggleWrongSource,
  });

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
        if (!isUser && msg.role == 'assistant')
          Padding(
            padding: const EdgeInsets.only(left: 6, right: 6, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _tinyIcon(
                  context,
                  icon: Icons.thumb_up_alt_outlined,
                  selected: msg.vote == 1,
                  tooltip: 'Helpful',
                  onTap: () => onVote(msg.vote == 1 ? null : 1),
                ),
                _tinyIcon(
                  context,
                  icon: Icons.thumb_down_alt_outlined,
                  selected: msg.vote == -1,
                  tooltip: 'Not helpful',
                  onTap: () => onVote(msg.vote == -1 ? null : -1),
                ),
                _tinyIcon(
                  context,
                  icon: msg.wrongSource ? Icons.link_off : Icons.link,
                  selected: msg.wrongSource,
                  tooltip: msg.wrongSource ? 'Wrong source (marked)' : 'Mark wrong source',
                  onTap: onToggleWrongSource,
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
      ],
    );
  }


  Widget _tinyIcon(
    BuildContext context, {
    required IconData icon,
    required bool selected,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final color = selected ? cs.primary : cs.onSurfaceVariant;
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(2),
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      iconSize: 18,
      icon: Icon(icon, color: color),
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

// Intentionally tiny struct for web results.
// forUser: readable list for UI
// forPrompt: compact list for model conditioning
class _WebBundle {
  final String forUser;
  final String forPrompt;
  const _WebBundle({required this.forUser, required this.forPrompt});
}

class _DownvoteDetailsResult {
  final String reason;
  final String details;
  const _DownvoteDetailsResult({required this.reason, required this.details});
}

class _DownvoteDetailsSheet extends StatefulWidget {
  const _DownvoteDetailsSheet();

  @override
  State<_DownvoteDetailsSheet> createState() => _DownvoteDetailsSheetState();
}

class _DownvoteDetailsSheetState extends State<_DownvoteDetailsSheet> {
  String _reason = 'Wrong source / stale';
  final _detailsCtrl = TextEditingController();

  @override
  void dispose() {
    _detailsCtrl.dispose();
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Quick feedback', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            _radio('Wrong source / stale'),
            _radio('Too long'),
            _radio('Stop asking questions'),
            _radio('Other'),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Optional details',
                hintText: 'One sentence is plenty…',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        _DownvoteDetailsResult(
                          reason: _reason,
                          details: _detailsCtrl.text,
                        ),
                      );
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _radio(String label) {
    return RadioListTile<String>(
      value: label,
      groupValue: _reason,
      onChanged: (v) => setState(() => _reason = v ?? _reason),
      title: Text(label),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}