import 'package:flutter/material.dart';

import '../../data/repositories/automation_rule_repo.dart';
import '../../services/ai/ai_key.dart';
import '../../services/ai/ai_settings.dart';
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
  bool _aiEnabled = false;
  String _keyStatus = 'Not set';

  @override
  void initState() {
    super.initState();
    _rulesFuture = AutomationRuleRepo.instance.list();
    _loadAi();
  }

  Future<void> _loadAi() async {
    final enabled = await AiSettings.isEnabled();
    final key = (await AiKey.get())?.trim();
    if (!mounted) return;
    setState(() {
      _aiEnabled = enabled;
      _keyStatus = (key == null || key.isEmpty) ? 'Not set' : 'Saved';
    });
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
            'AI (Opt-in)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: const Text('Enable AI augmentation (sticky)'),
              subtitle: const Text('When OFF, the app remains local-first. When ON, Ready Room can use AI after local→trusted→web.'),
              value: _aiEnabled,
              onChanged: (v) async {
                await AiSettings.setEnabled(v);
                await JsonlLogger.instance.log('ai_toggle', {'enabled': v});
                if (!mounted) return;
                setState(() => _aiEnabled = v);
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.key),
              title: const Text('OpenAI API Key'),
              subtitle: Text('Status: $_keyStatus'),
              onTap: () async {
                final controller = TextEditingController(text: (await AiKey.get()) ?? '');
                if (!context.mounted) return;
                final saved = await showDialog<bool>(
                  context: context,
                  builder: (ctx) {
                    return AlertDialog(
                      title: const Text('OpenAI API Key'),
                      content: TextField(
                        controller: controller,
                        decoration: const InputDecoration(hintText: 'sk-...'),
                        obscureText: true,
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () async {
                            final v = controller.text.trim();
                            if (v.isEmpty) {
                              await AiKey.clear();
                            } else {
                              await AiKey.set(v);
                            }
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    );
                  },
                );
                if (saved == true) {
                  await _loadAi();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI key saved')));
                  }
                }
              },
            ),
          ),

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
