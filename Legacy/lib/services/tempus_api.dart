import 'dart:convert';

import 'package:http/http.dart' as http;

// This file talks to the backend API.
// Plain-English: "send stuff to the server".
// If the server is down, this should fail gracefully.
class TempusApi {
  // Android emulator -> host machine mapping
  static const String _baseUrl = 'http://10.0.2.2:8000';

  // Backend route from backend/app/api/routes/events.py
  static const String _ingestPath = '/events';

  Future<bool> ingestEvent({
    required String source,
    required Map<String, dynamic> raw,
  }) async {
    final uri = Uri.parse('$_baseUrl$_ingestPath');

    final body = {
      'source': source,
      'raw_content': jsonEncode(raw),
    };

    try {
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 2));

      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
