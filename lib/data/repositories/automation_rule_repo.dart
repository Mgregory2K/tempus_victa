import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/app_db.dart';
import '../models/automation_rule.dart';

class AutomationRuleRepo {
  AutomationRuleRepo._();
  static final AutomationRuleRepo instance = AutomationRuleRepo._();
  static const _uuid = Uuid();

  Future<List<AutomationRule>> list({bool includeDisabled = true}) async {
    final d = await AppDb.instance.db;
    final rows = await d.query(
      'automation_rules',
      orderBy: 'updated_at_utc DESC',
    );
    final rules = rows.map((e) => AutomationRule.fromRow(e)).toList();
    if (includeDisabled) return rules;
    return rules.where((r) => r.enabled).toList();
  }

  Future<AutomationRule> create({
    required String name,
    required String trigger,
    required String action,
    double threshold = 0.85,
    bool enabled = false,
  }) async {
    final d = await AppDb.instance.db;
    final now = DateTime.now().toUtc();
    final r = AutomationRule(
      id: _uuid.v4(),
      name: name,
      trigger: trigger,
      action: action,
      threshold: threshold,
      enabled: enabled,
      createdAtUtc: now,
      updatedAtUtc: now,
    );
    await d.insert('automation_rules', r.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    return r;
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final d = await AppDb.instance.db;
    await d.update(
      'automation_rules',
      {
        'enabled': enabled ? 1 : 0,
        'updated_at_utc': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
