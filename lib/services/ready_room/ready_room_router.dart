import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../../data/repositories/signal_repo.dart';
import '../../data/repositories/task_repo.dart';
import '../../services/ai/ai_key.dart';
import '../../services/ai/ai_settings.dart';
import '../../services/ai/openai_client.dart';

class ReadyRoomResult {
  final String title;
  final String body;
  final List<ReadyRoomLink> links;

  const ReadyRoomResult({required this.title, required this.body, this.links = const []});
}

class ReadyRoomLink {
  final String title;
  final String url;
  const ReadyRoomLink({required this.title, required this.url});
}

/// Tempus Victa Ready Room Router (local-first).
///
/// Pipeline (textbook): Local → Trusted Sources Cache → Web → AI (if enabled).
class ReadyRoomRouter {
  static Future<ReadyRoomResult> route(String input) async {
    final q = input.trim();
    if (q.isEmpty) return const ReadyRoomResult(title: 'Empty', body: '');

    // 0) Self-awareness / app knowledge
    final lower = q.toLowerCase();
    if (_looksLikeHowTo(lower) || lower.contains('api key') || lower.contains('ai toggle') || lower.contains('permissions')) {
      final knowledge = await rootBundle.loadString('assets/app_knowledge.txt');
      return ReadyRoomResult(title: 'App knowledge (local)', body: knowledge.trim());
    }

    // 1) Local search: tasks + inbox signals
    final local = await _localSearch(q);
    if (local != null) return local;

    // 2) Trusted Sources Cache (domain compass)
    final trusted = await _trustedSourcesHint(q);
    if (trusted != null) return trusted;

    // 3) Web research (best-effort)
    final web = await _webSearch(q);
    if (web != null) return web;

    // 4) AI augmentation (optional & gated)
    final ai = await _aiAssist(q);
    if (ai != null) return ai;

    return ReadyRoomResult(
      title: 'No match yet',
      body: 'I checked local data, trusted sources, and web research but didn\'t find a confident result. Try rephrasing or be more specific.',
    );
  }

  static bool _looksLikeHowTo(String lower) {
    return lower.startsWith('how ') || lower.startsWith('how do ') || lower.startsWith('what is ') || lower.startsWith('where ') || lower.endsWith('?');
  }

  static Future<ReadyRoomResult?> _localSearch(String q) async {
    // Quick local search heuristic.
    final tasks = await TaskRepo.instance.search(q, limit: 5);
    final signals = await SignalRepo.instance.search(q, limit: 5);

    if (tasks.isEmpty && signals.isEmpty) return null;

    final b = StringBuffer();
    if (tasks.isNotEmpty) {
      b.writeln('Local Tasks (top matches):');
      for (final t in tasks) {
        b.writeln('• ${t.title}  [${t.status}]');
      }
      b.writeln();
    }
    if (signals.isNotEmpty) {
      b.writeln('Local Signals (top matches):');
      for (final s in signals) {
        final preview = (s.transcript?.trim().isNotEmpty == true) ? s.transcript!.trim() : (s.text ?? '').trim();
        b.writeln('• ${preview.isEmpty ? '(empty)' : preview}  (source=${s.source}, status=${s.status})');
      }
    }

    return ReadyRoomResult(title: 'Local results', body: b.toString().trim());
  }

  static Future<ReadyRoomResult?> _trustedSourcesHint(String q) async {
    // This is intentionally lightweight: the cache is a compass, not a library.
    final raw = await rootBundle.loadString('assets/trusted_sources_active.json');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final domains = (j['domains'] as List?)?.cast<Map>() ?? const [];

    // If query contains a domain-ish token, see if it is in trusted cache.
    final token = q.split(RegExp(r'\s+')).firstWhere(
          (t) => t.contains('.') && !t.startsWith('http'),
          orElse: () => '',
        );
    if (token.isEmpty) return null;

    final found = domains.where((d) => (d['domain']?.toString() ?? '').toLowerCase() == token.toLowerCase()).toList();
    if (found.isEmpty) return null;

    final trust = found.first['trust'];
    return ReadyRoomResult(
      title: 'Trusted Sources Cache',
      body: 'Domain "$token" is in your active trusted cache (trust=$trust). If you\'re researching this topic, prefer sources from this domain when possible.',
      links: [ReadyRoomLink(title: token, url: 'https://$token')],
    );
  }

  static Future<ReadyRoomResult?> _webSearch(String q) async {
    // Best-effort web research using DuckDuckGo HTML results.
    // If offline or blocked, we gracefully return null (so AI may still help if enabled).
    try {
      final uri = Uri.parse('https://duckduckgo.com/html/?q=${Uri.encodeComponent(q)}');
      final res = await http.get(uri, headers: {'User-Agent': 'TempusVicta/0.1'}).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final html = res.body;
      final results = <ReadyRoomLink>[];

      // Extremely small parser: looks for "result__a" anchors.
      final re = RegExp(r'<a[^>]*class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>', caseSensitive: false);
      for (final m in re.allMatches(html)) {
        if (results.length >= 5) break;
        final url = _htmlDecode(m.group(1) ?? '').trim();
        final title = _stripTags(_htmlDecode(m.group(2) ?? '').trim());
        if (url.isEmpty || title.isEmpty) continue;
        results.add(ReadyRoomLink(title: title, url: url));
      }

      if (results.isEmpty) return null;

      final b = StringBuffer();
      b.writeln('Web research (top links):');
      for (final r in results) {
        b.writeln('• ${r.title}');
      }

      return ReadyRoomResult(title: 'Web research', body: b.toString().trim(), links: results);
    } catch (_) {
      return null;
    }
  }

  static Future<ReadyRoomResult?> _aiAssist(String q) async {
    if (!await AiSettings.isEnabled()) return null;
    final key = (await AiKey.get())?.trim();
    if (key == null || key.isEmpty) {
      return const ReadyRoomResult(
        title: 'AI enabled, but no API key',
        body: 'AI is ON, but no OpenAI API key is stored. Add your key in Settings or Bridge (key icon).',
      );
    }

    // Minimal: use AI only for routing label suggestions right now.
    // Full conversational AI response can be layered later.
    final label = await OpenAiClient.assistLabel(apiKey: key, input: q);
    if (label == null) return null;

    return ReadyRoomResult(
      title: 'AI routing assist',
      body: 'AI suggests intent: $label\n\n(Next step: wire this to create/route objects automatically when confidence thresholds are met.)',
    );
  }

  static String _stripTags(String s) => s.replaceAll(RegExp(r'<[^>]+>'), '').trim();

  static String _htmlDecode(String s) {
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
}
