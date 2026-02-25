import 'package:flutter/services.dart';

class ShareIngestor {
  static const MethodChannel _ch = MethodChannel('tempus/share');

  /// Returns list of shares:
  /// { kind: 'text'|'link'|'image', text?, subject?, uri?, mimeType?, tsMs }
  static Future<List<Map<String, dynamic>>> fetchAndClearShares() async {
    try {
      final raw = await _ch.invokeMethod<List<dynamic>>('fetchAndClearShares');
      if (raw == null) return const [];
      return raw.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
