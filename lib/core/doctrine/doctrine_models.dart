import '../twin_plus/router.dart';

class DoctrineRequest {
  final String surface;
  final String inputText;
  final List<String> recentUserTurns;

  /// 'now'|'today'|'week'|'month'|'timeless'
  final String timeHorizon;

  /// When true, Twin+ should prefer verifiable sources and avoid overconfident synthesis.
  final bool needsVerifiableFacts;

  /// Optional task type hint (heuristic).
  final TaskType taskType;

  final DateTime? deadlineUtc;

  /// Internal-only: when true, DoctrineEngine includes debugTrace.
  final bool devMode;

  const DoctrineRequest({
    required this.surface,
    required this.inputText,
    this.recentUserTurns = const <String>[],
    this.timeHorizon = 'today',
    this.needsVerifiableFacts = false,
    this.taskType = TaskType.unknown,
    this.deadlineUtc,
    this.devMode = false,
  });

  QueryIntent toQueryIntent() => QueryIntent(
        surface: surface,
        queryText: inputText,
        taskType: taskType,
        timeHorizon: timeHorizon,
        needsVerifiableFacts: needsVerifiableFacts,
        deadlineUtc: deadlineUtc,
        recentUserTurns: recentUserTurns,
      );
}
