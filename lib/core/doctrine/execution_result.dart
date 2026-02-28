
class ExecutionResult {
  final String? entityType;
  final String? entityId;
  final bool success;

  ExecutionResult({
    required this.success,
    this.entityType,
    this.entityId,
  });
}
