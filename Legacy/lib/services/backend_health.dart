import 'dart:convert';

import 'package:http/http.dart' as http;

// This file checks the backend health.
// It should be fast and quiet.
class BackendHealth {
  final String baseUrl;

  BackendHealth({required this.baseUrl});

  Future<bool> check() async {
    try {
      final r = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 2));

      if (r.statusCode != 200) return false;

      final data = jsonDecode(r.body);

      // Support both shapes:
      // {"ok": true}
      // {"status": "ok"}
      if (data is Map) {
        if (data['ok'] == true) return true;
        if ((data['status'] ?? '').toString().toLowerCase() == 'ok') return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }
}
