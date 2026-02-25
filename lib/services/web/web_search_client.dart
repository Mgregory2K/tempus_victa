import 'dart:convert';
import 'dart:io';

/// Minimal, dependency-free web lookup.
///
/// IMPORTANT:
/// - This is NOT AI.
/// - Uses standard internet to return useful context when AI is disabled.
/// - No branding; the UI can present results generically.
///
/// Primary backend: DuckDuckGo Instant Answer API.
/// It returns JSON with "AbstractText" and "RelatedTopics".
class WebSearchClient {
  final HttpClient _http;
  WebSearchClient({HttpClient? http}) : _http = http ?? HttpClient();

  Future<WebSearchResponse> search(String query, {int maxLinks = 5}) async {
    final q = query.trim();
    if (q.isEmpty) return const WebSearchResponse(query: '', ok: false, error: 'Empty query');

    final uri = Uri.https('api.duckduckgo.com', '/', {
      'q': q,
      'format': 'json',
      'no_redirect': '1',
      'no_html': '1',
      'skip_disambig': '1',
    });

    try {
      final req = await _http.getUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return WebSearchResponse(query: q, ok: false, error: 'HTTP ${res.statusCode}');
      }

      final data = jsonDecode(body);
      final abstractText = (data is Map && data['AbstractText'] is String) ? (data['AbstractText'] as String) : '';

      final links = <WebSearchLink>[];
      void addTopic(dynamic t) {
        if (t is Map) {
          final text = (t['Text'] is String) ? (t['Text'] as String) : null;
          final url = (t['FirstURL'] is String) ? (t['FirstURL'] as String) : null;
          if (text != null && url != null) {
            links.add(WebSearchLink(titleOrSnippet: text, url: url));
          }
        }
      }

      final related = (data is Map) ? data['RelatedTopics'] : null;
      if (related is List) {
        for (final item in related) {
          if (links.length >= maxLinks) break;
          if (item is Map && item['Topics'] is List) {
            for (final sub in (item['Topics'] as List)) {
              if (links.length >= maxLinks) break;
              addTopic(sub);
            }
          } else {
            addTopic(item);
          }
        }
      }

      return WebSearchResponse(
        query: q,
        ok: true,
        abstractText: abstractText.trim().isEmpty ? null : abstractText.trim(),
        links: links,
      );
    } catch (e) {
      return WebSearchResponse(query: q, ok: false, error: e.toString());
    }
  }
}

class WebSearchResponse {
  final String query;
  final bool ok;
  final String? abstractText;
  final List<WebSearchLink> links;
  final String? error;

  const WebSearchResponse({
    required this.query,
    required this.ok,
    this.abstractText,
    this.links = const <WebSearchLink>[],
    this.error,
  });
}

class WebSearchLink {
  final String titleOrSnippet;
  final String url;
  const WebSearchLink({required this.titleOrSnippet, required this.url});

  /// Back-compat getters for DoctrineEngine.
  String get title => titleOrSnippet;

  /// DuckDuckGo Instant Answer API does not provide a separate snippet; use the same field.
  String get snippet => titleOrSnippet;

  /// Parsed host from the URL (best-effort).
  String get domain {
    try {
      final u = Uri.parse(url);
      return u.host;
    } catch (_) {
      return '';
    }
  }
}
