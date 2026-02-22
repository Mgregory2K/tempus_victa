import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../ai/ai_settings.dart';

class RoutingStep {
  final String name;
  final Map<String, dynamic> data;
  const RoutingStep(this.name, this.data);

  Map<String, dynamic> toJson() => {'name': name, 'data': data};
}

class RoutingResult {
  final String traceId;
  final String responseText;
  final List<RoutingStep> steps;
  const RoutingResult({
    required this.traceId,
    required this.responseText,
    required this.steps,
  });
}

/// Deterministic routing cascade (Phase 0/1 safe mode).
/// - No DB dependencies (keeps app resilient if schema changes)
/// - AI is optional + opt-in, and never overrides local steps
class AssistantRouter {
  AssistantRouter._();
  static final AssistantRouter I = AssistantRouter._();

  final _uuid = const Uuid();

  Future<RoutingResult> route(String input, {bool protocolMode = false}) async {
    final q = input.trim();
    final steps = <RoutingStep>[];
    final traceId = _uuid.v4();

    if (q.isEmpty) {
      return RoutingResult(traceId: traceId, responseText: '', steps: const []);
    }

    steps.add(RoutingStep('input', {'text': q, 'protocolMode': protocolMode}));

    // 1) Local deterministic responders (v1)
    final lower = q.toLowerCase();
    if (lower == 'ping') {
      steps.add(const RoutingStep('local.ping', {'ok': true}));
      return RoutingResult(traceId: traceId, responseText: 'pong', steps: steps);
    }

    if (lower.contains('help') || lower.contains('what can you do')) {
      steps.add(const RoutingStep('local.help', {}));
      final response = [
        'Tempus Victa (local-first) Ready Room',
        '- Type or use the mic',
        '- AI is optional (Settings) and requires an API key',
        '- Core capture happens on the Bridge (one-button capture)',
      ].join('\n');
      return RoutingResult(traceId: traceId, responseText: response, steps: steps);
    }

    // 2) AI (optional, opt-in)
    final aiEnabled = await AiSettings.getEnabled();
    final apiKey = await AiSettings.getApiKey();

    if (aiEnabled && apiKey != null && apiKey.trim().isNotEmpty) {
      steps.add(const RoutingStep('ai.opt_in', {'enabled': true}));

      try {
        final endpoint = await AiSettings.getEndpoint();
        if (endpoint == null || endpoint.trim().isEmpty) {
          steps.add(const RoutingStep('ai.no_endpoint', {}));
        } else {
          final resp = await http.post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${apiKey.trim()}',
            },
            body: jsonEncode({'input': q, 'traceId': traceId}),
          );

          steps.add(RoutingStep('ai.http', {
            'status': resp.statusCode,
            'bytes': resp.bodyBytes.length,
          }));

          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            final decoded = jsonDecode(resp.body);
            final text = (decoded is Map && decoded['text'] is String) ? decoded['text'] as String : resp.body;
            return RoutingResult(traceId: traceId, responseText: text, steps: steps);
          }
        }
      } catch (e) {
        steps.add(RoutingStep('ai.error', {'error': e.toString()}));
      }
    }

    // 3) Fallback: deterministic capture-for-follow-up behavior
    steps.add(const RoutingStep('fallback', {'behavior': 'return_input'}));
    return RoutingResult(
      traceId: traceId,
      responseText: 'Captured. (No AI response — AI disabled or not configured.)\n\nYou said: $q',
      steps: steps,
    );
  }
}
