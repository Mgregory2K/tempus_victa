import 'package:flutter/material.dart';

import '../../services/ai/ai_settings_store.dart';
import '../../services/ai/openai_client.dart';
import '../room_frame.dart';

class SettingsRoom extends StatefulWidget {
  final String roomName;
  const SettingsRoom({super.key, required this.roomName});

  @override
  State<SettingsRoom> createState() => _SettingsRoomState();
}

class _SettingsRoomState extends State<SettingsRoom> {
  bool _loading = true;
  bool _aiEnabled = false;
  final _apiKeyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final enabled = await AiSettingsStore.isEnabled();
    final key = await AiSettingsStore.getApiKey();
    final model = await AiSettingsStore.getModel();
    if (!mounted) return;
    setState(() {
      _aiEnabled = enabled;
      _apiKeyCtrl.text = key ?? '';
      _modelCtrl.text = model;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await AiSettingsStore.setEnabled(_aiEnabled);
    await AiSettingsStore.setApiKey(_apiKeyCtrl.text);
    await AiSettingsStore.setModel(_modelCtrl.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved')),
    );
  }

  Future<void> _testConnection() async {
    // Persist current form values so other rooms see the same state immediately.
    await AiSettingsStore.setApiKey(_apiKeyCtrl.text);
    await AiSettingsStore.setModel(_modelCtrl.text);
    await AiSettingsStore.setEnabled(_aiEnabled);

    final enabled = _aiEnabled;
    final key = _apiKeyCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI is disabled. Enable it first.')),
      );
      return;
    }
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste an OpenAI API key first.')),
      );
      return;
    }
    if (model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model cannot be empty.')),
      );
      return;
    }

    setState(() => _testing = true);
    final client = OpenAiClient(apiKey: key, model: model);
    final resp = await client.respondText(
      input: 'Say "Tempus Victa online" and nothing else.',
      instructions: 'You are the Tempus Victa assistant. Keep answers brief unless asked otherwise.',
      maxOutputTokens: 30,
    );
    if (!mounted) return;
    setState(() => _testing = false);

    // If the test succeeds, keep AI enabled and saved. Users expect "it worked" to mean it's on.
    if (resp.ok && mounted) {
      await AiSettingsStore.setEnabled(true);
      setState(() => _aiEnabled = true);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(resp.ok ? resp.text : (resp.error ?? 'Failed'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return RoomFrame(
        title: widget.roomName,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return RoomFrame(
      title: widget.roomName,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'AI (Opt-in)',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable AI augmentation'),
            subtitle: const Text('Baseline features must work without AI.'),
            value: _aiEnabled,
            onChanged: (v) async {
              setState(() => _aiEnabled = v);
              await AiSettingsStore.setEnabled(v);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKeyCtrl,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'OpenAI API Key',
              hintText: 'sk-…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelCtrl,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Model',
              hintText: 'gpt-4o-mini',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering_rounded),
                  label: Text(_testing ? 'Testing…' : 'Test connection'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Ingestion controls',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Next: move notification ingestion wiring + debug toggles here (not Signal Bay).',
          ),
        ],
      ),
    );
  }
}
