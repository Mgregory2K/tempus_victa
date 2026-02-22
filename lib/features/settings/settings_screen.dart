import 'package:flutter/material.dart';

import '../../data/repositories/automation_rule_repo.dart';
import '../../services/logging/jsonl_logger.dart';
import '../../ui/tempus_scaffold.dart';
import '../../data/models/automation_rule.dart';

class SettingsScreen extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavigate;

  const SettingsScreen({
    super.key,
    required this.selectedIndex,
    required this.onNavigate,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<List<AutomationRule>> _rulesFuture;

  @override
  void initState() {
    super.initState();
    _rulesFuture = AutomationRuleRepo.instance.list();
  }

  void _reload() => setState(() => _rulesFuture = AutomationRuleRepo.instance.list());

  Future<void> _seedRule() async {
    await AutomationRuleRepo.instance.create(
      name: 'Auto-route notifications to Inbox Tasks',
      trigger: 'notification',
      action: 'route_to:tasks',
      threshold: 0.85,
      enabled: false,
    );
    await JsonlLogger.instance.log('seed_rule', {'name': 'Auto-route notifications to Inbox Tasks'});
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return TempusScaffold(
      title: 'Settings',
      selectedIndex: widget.selectedIndex,
      onNavigate: widget.onNavigate,
      actions: [
        IconButton(
          tooltip: 'Seed Rule',
          onPressed: _seedRule,
          icon: const Icon(Icons.add),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text(
            'Automation Rules (local-first)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<AutomationRule>>(
            future: _rulesFuture,
            builder: (context, snap) {
              final rules = snap.data ?? const <AutomationRule>[];
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (rules.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No rules yet. Tap + to seed a starter rule.'),
                );
              }
              return Column(
                children: rules.map((r) {
                  return Card(
                    child: ListTile(
                      title: Text(r.name),
                      subtitle: Text('trigger=${r.trigger}  action=${r.action}\nthresh=${r.threshold.toStringAsFixed(2)}'),
                      trailing: Switch(
                        value: r.enabled,
                        onChanged: (v) async {
                          await AutomationRuleRepo.instance.setEnabled(r.id, v);
                          await JsonlLogger.instance.log('rule_toggle', {'id': r.id, 'enabled': v});
                          _reload();
                        },
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Logs',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Write test event'),
              subtitle: const Text('Confirms JSONL pipeline is alive.'),
              onTap: () async {
                await JsonlLogger.instance.log('settings_test', {'ok': true});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logged settings_test to events.jsonl')),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Next: add Export/Import + Notification Access deep-link.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
