import '../twin_plus/router.dart';

class DoctrineRequest {
  final String surface;
  final String inputText;
  final List<String> recentUserTurns;

  /// 'now'|'today'|'week'|'month'|'timeless'
  final String timeHorizon;

  final DateTime? deadlineUtc;

  /// Internal-only: when true, DoctrineEngine includes debugTrace.
  final bool devMode;

  const DoctrineRequest({
    required this.surface,
    required this.inputText,
    this.recentUserTurns = const <String>[],
    this.timeHorizon = 'today',
    this.deadlineUtc,
    this.devMode = false,
  });

  QueryIntent toQueryIntent() => QueryIntent(
        surface: surface,
        queryText: inputText,
        timeHorizon: timeHorizon,
        deadlineUtc: deadlineUtc,
        recentUserTurns: recentUserTurns,
      );
}
