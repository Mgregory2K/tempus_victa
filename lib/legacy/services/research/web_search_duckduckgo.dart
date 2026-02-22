import 'dart:convert';
import 'package:http/http.dart' as http;

class WebSearchResult {
  final String title;
  final String snippet;
  final String url;

  WebSearchResult({
    required this.title,
    required this.snippet,
    required this.url,
  });
}

class DuckDuckGoSearch {
  static Future<List<WebSearchResult>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    try {
      final results = await _instantAnswerSearch(q);

      if (results.isNotEmpty) {
        return results;
      }
    } catch (_) {
      // swallow errors — we will fallback
    }

    // 🔥 Guaranteed fallback
    final encoded = Uri.encodeComponent(q);

    return [
      WebSearchResult(
        title: 'Search the web',
        snippet:
            'No instant-answer results were found. Tap to open full search results.',
        url: 'https://duckduckgo.com/?q=$encoded',
        // If you prefer Google:
        // url: 'https://www.google.com/search?q=$encoded',
      ),
    ];
  }

  // ---- Instant Answer API ----
  static Future<List<WebSearchResult>> _instantAnswerSearch(
      String query) async {
    final encoded = Uri.encodeComponent(query);
    final url =
        Uri.parse('https://api.duckduckgo.com/?q=$encoded&format=json&no_redirect=1');

    final response = await http.get(url);

    if (response.statusCode != 200) {
      return [];
    }

    final jsonMap = jsonDecode(response.body);

    final results = <WebSearchResult>[];

    // Abstract
    final abstractText = (jsonMap['AbstractText'] ?? '').toString();
    final abstractUrl = (jsonMap['AbstractURL'] ?? '').toString();
    final heading = (jsonMap['Heading'] ?? '').toString();

    if (abstractText.isNotEmpty && abstractUrl.isNotEmpty) {
      results.add(
        WebSearchResult(
          title: heading.isNotEmpty ? heading : 'Reference',
          snippet: abstractText,
          url: abstractUrl,
        ),
      );
    }

    // Related Topics
    final related = jsonMap['RelatedTopics'];
    if (related is List) {
      for (final item in related) {
        if (item is Map) {
          final text = (item['Text'] ?? '').toString();
          final firstUrl = (item['FirstURL'] ?? '').toString();

          if (text.isNotEmpty && firstUrl.isNotEmpty) {
            results.add(
              WebSearchResult(
                title: text.split(' - ').first,
                snippet: text,
                url: firstUrl,
              ),
            );
          }
        }
      }
    }

    return results;
  }
}
