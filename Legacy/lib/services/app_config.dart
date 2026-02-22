import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Local-first runtime config.
/// Stored on-device so the app can survive restarts and run offline.
///
/// Canonical storage location (Android): /data/data/<pkg>/files
/// (via getApplicationSupportDirectory).
class AppConfig {
  final String baseUrl;
  final String? jwt;

  const AppConfig({
    required this.baseUrl,
    required this.jwt,
  });

  static const String _fileName = 'config.json';

  // Defaults:
  // - Physical device on LAN should hit the host at its LAN IP.
  // - Emulator uses 10.0.2.2.
  static const String defaultBaseUrl = 'http://192.168.40.250:8000';

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<AppConfig> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) {
        return const AppConfig(baseUrl: defaultBaseUrl, jwt: null);
      }
      final txt = await f.readAsString();
      final m = jsonDecode(txt) as Map<String, dynamic>;
      final baseUrl = (m['baseUrl'] ?? defaultBaseUrl).toString().trim();
      final jwtRaw = m['jwt'];
      final jwt = (jwtRaw == null) ? null : jwtRaw.toString().trim();
      return AppConfig(
        baseUrl: baseUrl.isEmpty ? defaultBaseUrl : baseUrl,
        jwt: (jwt == null || jwt.isEmpty) ? null : jwt,
      );
    } catch (_) {
      // Config should never crash the app.
      return const AppConfig(baseUrl: defaultBaseUrl, jwt: null);
    }
  }

  static Future<void> save({required String baseUrl, String? jwt}) async {
    final f = await _file();
    await f.parent.create(recursive: true);
    final obj = {
      'baseUrl': baseUrl.trim(),
      'jwt': (jwt ?? '').trim(),
      'savedAt': DateTime.now().toIso8601String(),
    };
    await f.writeAsString(jsonEncode(obj), flush: true);
  }
}
