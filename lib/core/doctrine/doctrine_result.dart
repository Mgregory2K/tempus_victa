class DoctrineWebResult {
  final String title;
  final String snippet;
  final String url;
  final String domain;

  const DoctrineWebResult({
    required this.title,
    required this.snippet,
    required this.url,
    required this.domain,
  });
}

class DoctrineResult {
  final String decisionId;

  /// Renderable answer text (already shaped for the surface).
  final String text;

  /// Structured web results (may be empty).
  final List<DoctrineWebResult> webResults;

  /// Always present when web/ai fails or yields nothing.
  final List<String> fallbackLinks;

  /// Debuggable info for internal display (optional).
  final List<String> reasonCodes;

  /// Internal-only trace lines for Dev Mode UI.
  final List<String> debugTrace;

  const DoctrineResult({
    required this.decisionId,
    required this.text,
    this.webResults = const <DoctrineWebResult>[],
    this.fallbackLinks = const <String>[],
    this.reasonCodes = const <String>[],
    this.debugTrace = const <String>[],
  });
}
