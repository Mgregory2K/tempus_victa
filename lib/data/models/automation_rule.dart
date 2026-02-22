class AutomationRule {
  final String id;
  final String name;
  final String trigger; // e.g. "route:android_notification:*"
  final String action;  // e.g. "route_to:tasks" or "create_task"
  final double threshold;
  final bool enabled;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  const AutomationRule({
    required this.id,
    required this.name,
    required this.trigger,
    required this.action,
    required this.threshold,
    required this.enabled,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  factory AutomationRule.fromRow(Map<String, Object?> row) {
    return AutomationRule(
      id: row['id'] as String,
      name: (row['name'] as String?) ?? 'Rule',
      trigger: (row['trigger'] as String?) ?? '',
      action: (row['action'] as String?) ?? '',
      threshold: (row['threshold'] as num?)?.toDouble() ?? 0.85,
      enabled: ((row['enabled'] as int?) ?? 0) == 1,
      createdAtUtc: DateTime.parse(row['created_at_utc'] as String),
      updatedAtUtc: DateTime.parse(row['updated_at_utc'] as String),
    );
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'trigger': trigger,
        'action': action,
        'threshold': threshold,
        'enabled': enabled ? 1 : 0,
        'created_at_utc': createdAtUtc.toIso8601String(),
        'updated_at_utc': updatedAtUtc.toIso8601String(),
      };
}
