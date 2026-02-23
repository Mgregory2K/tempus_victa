import 'dart:convert';
import 'dart:io';

/// Minimal OpenAI Responses API client using dart:io.
///
/// - AI is opt-in.
/// - Network errors must be handled gracefully.
/// - Do not depend on this for baseline app behavior.
///
/// API reference: https://api.openai.com/v1/responses
class OpenAiClient {
  final String apiKey;
  final String model;

  OpenAiClient({required this.apiKey, required this.model});

  static const _host = 'api.openai.com';
  static const _path = '/v1/responses';

  Future<OpenAiTextResponse> respondText({
    required String input,
    String? instructions,
    int maxOutputTokens = 600,
  }) async {
    final uri = Uri.https(_host, _path);

    final body = <String, dynamic>{
      'model': model,
      'input': input,
      'max_output_tokens': maxOutputTokens,
      'store': false,
    };
    if (instructions != null && instructions.trim().isNotEmpty) {
      body['instructions'] = instructions.trim();
    }

    final client = HttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.add(utf8.encode(jsonEncode(body)));

      final res = await req.close();
      final raw = await utf8.decodeStream(res);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        // Try to parse an OpenAI error payload, but never assume a shape.
        String msg = 'HTTP ${res.statusCode}';
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map && decoded['error'] is Map) {
            final err = decoded['error'] as Map;
            final m = err['message'];
            if (m is String && m.trim().isNotEmpty) msg = m.trim();
          }
        } catch (_) {
          // ignore
        }
        return OpenAiTextResponse(text: '', error: msg);
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return OpenAiTextResponse(text: '', error: 'Unexpected response');
      }

      // Extract assistant text:
      // response.output[] -> items of type "message" -> content[] -> type "output_text" -> text
      final out = decoded['output'];
      if (out is! List) {
        return OpenAiTextResponse(text: '', error: 'No output');
      }

      final buf = StringBuffer();
      for (final item in out) {
        if (item is! Map) continue;
        if (item['type'] != 'message') continue;
        final content = item['content'];
        if (content is! List) continue;
        for (final c in content) {
          if (c is! Map) continue;
          if (c['type'] == 'output_text' && c['text'] is String) {
            buf.writeln((c['text'] as String).trimRight());
          }
        }
      }

      final text = buf.toString().trim();
      if (text.isEmpty) {
        return OpenAiTextResponse(text: '', error: 'Empty response');
      }
      return OpenAiTextResponse(text: text);
    } on SocketException {
      return OpenAiTextResponse(text: '', error: 'No network connection');
    } on HandshakeException {
      return OpenAiTextResponse(text: '', error: 'TLS handshake failed');
    } catch (_) {
      return OpenAiTextResponse(text: '', error: 'Request failed');
    } finally {
      client.close(force: true);
    }
  }
}

class OpenAiTextResponse {
  final String text;
  final String? error;
  bool get ok => error == null;

  OpenAiTextResponse({required this.text, this.error});
}
