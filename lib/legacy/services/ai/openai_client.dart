import 'dart:convert';
import 'dart:io';

import 'ai_settings.dart';

class AiAssistResult {
  final String? text;
  final String? error;
  final int? usedTokens;

  const AiAssistResult({this.text, this.error, this.usedTokens});

  bool get ok => text != null && text!.trim().isNotEmpty;
}

class OpenAiClient {
  static const String _host = 'api.openai.com';
  static const String _path = '/v1/responses';

  /// Detailed result so UI can show a human reason (cap, key, auth, rate-limit, etc.)
  static Future<AiAssistResult> tryAssistDetailed({
    required String prompt,
    String? systemHint,
    int plannedTokens = 2500,
  }) async {
    final enabled = await AiSettings.getEnabled();
    if (!enabled) return const AiAssistResult(error: 'AI is OFF.');

    final key = await AiSettings.getApiKey();
    if (key == null || key.isEmpty) return const AiAssistResult(error: 'No OpenAI API key set.');

    final okCap = await AiSettings.underCapOrDisabled(plannedTokens: plannedTokens);
    if (!okCap) {
      final cap = await AiSettings.getMonthlyCapTokens();
      final used = await AiSettings.getUsedMonthlyTokens();
      return AiAssistResult(error: 'AI cap exceeded. Used $used / $cap tokens this month.');
    }

    final model = await AiSettings.getModel();

    final reqBody = <String, dynamic>{
      'model': model,
      'input': _buildInput(prompt: prompt, systemHint: systemHint),
    };

    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.https(_host, _path));
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.write(jsonEncode(reqBody));

      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        if (resp.statusCode == 401) return const AiAssistResult(error: 'AI auth failed (bad API key).');
        if (resp.statusCode == 429) return const AiAssistResult(error: 'AI rate-limited. Try again in a minute.');
        return AiAssistResult(error: 'AI request failed (HTTP ${resp.statusCode}).');
      }

      final decoded = jsonDecode(body);
      final outputText = _extractOutputText(decoded);
      final used = _extractUsedTokens(decoded);

      if (used != null && used > 0) {
        await AiSettings.addUsedTokens(used);
      }

      final trimmed = outputText?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        return const AiAssistResult(error: 'AI returned no text.');
      }

      return AiAssistResult(text: trimmed, usedTokens: used);
    } catch (_) {
      return const AiAssistResult(error: 'AI network error.');
    } finally {
      client.close(force: true);
    }
  }

  /// Backwards compatible helper (returns text or null)
  static Future<String?> tryAssist({
    required String prompt,
    String? systemHint,
    int plannedTokens = 2500,
  }) async {
    final r = await tryAssistDetailed(prompt: prompt, systemHint: systemHint, plannedTokens: plannedTokens);
    return r.ok ? r.text : null;
  }

  static List<Map<String, dynamic>> _buildInput({required String prompt, String? systemHint}) {
    final items = <Map<String, dynamic>>[];
    if (systemHint != null && systemHint.trim().isNotEmpty) {
      items.add({
        'role': 'system',
        'content': [
          {'type': 'input_text', 'text': systemHint.trim()}
        ]
      });
    }
    items.add({
      'role': 'user',
      'content': [
        {'type': 'input_text', 'text': prompt}
      ]
    });
    return items;
  }

  static String? _extractOutputText(dynamic decoded) {
    try {
      final output = decoded['output'];
      if (output is List) {
        final buf = StringBuffer();
        for (final item in output) {
          final content = item['content'];
          if (content is List) {
            for (final c in content) {
              final type = (c['type'] ?? '').toString();
              if (type.contains('output_text') || type == 'text' || type.contains('text')) {
                final t = c['text'];
                if (t is String) buf.writeln(t);
              }
            }
          }
        }
        final s = buf.toString().trim();
        return s.isEmpty ? null : s;
      }
    } catch (_) {}
    return null;
  }

  static int? _extractUsedTokens(dynamic decoded) {
    try {
      final usage = decoded['usage'];
      if (usage is Map) {
        final inTok = usage['input_tokens'];
        final outTok = usage['output_tokens'];
        final a = (inTok is int) ? inTok : int.tryParse(inTok?.toString() ?? '');
        final b = (outTok is int) ? outTok : int.tryParse(outTok?.toString() ?? '');
        if (a != null || b != null) return (a ?? 0) + (b ?? 0);
      }
    } catch (_) {}
    return null;
  }
}
