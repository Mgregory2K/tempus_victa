// Tempus Vista rebuild - generated 2026-02-21
// Local-first, Android-first.


import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_settings.dart';

class OpenAiClient {
  // Put your key into Android env as needed or store in meta.
  // For now: read from meta key 'openai:api_key'. If missing -> AI disabled.
  static const _kApiKey = 'openai:api_key';
  static const _kModel = 'gpt-4o-mini';

  static Future<String?> tryRouteCommand(String text) async {
    // Deterministic first.
    final lower = text.trim().toLowerCase();
    if (lower.startsWith('create a task') || lower.startsWith('create task')) return 'task';
    if (lower.startsWith('create a project') || lower.startsWith('create project')) return 'project';
    if (lower.startsWith('create a reminder') || lower.startsWith('create reminder')) return 'reminder';
    return null;
  }

  static Future<String?> assistLabel({
    required String apiKey,
    required String input,
    int plannedTokens = 400,
  }) async {
    if (!await AiSettings.underCapOrDisabled(plannedTokens: plannedTokens)) return null;

    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final body = {
      'model': _kModel,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a routing assistant for a personal automation app. Return ONE WORD only: task, project, reminder, or unknown.'
        },
        {'role': 'user', 'content': input},
      ],
      'max_tokens': 8,
      'temperature': 0.1,
    };

    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final content = (((j['choices'] as List?)?.first as Map?)?['message'] as Map?)?['content'] as String?;
    if (content == null) return null;
    final out = content.trim().toLowerCase();
    if (out.contains('task')) return 'task';
    if (out.contains('project')) return 'project';
    if (out.contains('reminder')) return 'reminder';
    return 'unknown';
  }
}
