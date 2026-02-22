// Tempus Vista rebuild - generated 2026-02-21
// Local-first, Android-first.


import 'package:flutter/material.dart';

import '../services/voice/voice_service.dart';

class InputComposer extends StatefulWidget {
  final String hint;
  final Future<void> Function({String? text, String? transcript}) onSubmit;
  final bool autofocus;
  final bool enabled;

  const InputComposer({
    super.key,
    required this.onSubmit,
    this.hint = 'Type or use mic…',
    this.autofocus = false,
    this.enabled = true,
  });

  @override
  State<InputComposer> createState() => _InputComposerState();
}

class _InputComposerState extends State<InputComposer> {
  final _controller = TextEditingController();
  bool _listening = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    if (!widget.enabled) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await widget.onSubmit(text: text, transcript: null);
  }

  Future<void> _toggleMic() async {
    if (!widget.enabled) return;
    if (_listening) {
      await VoiceService.instance.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    final t = await VoiceService.instance.listenOnce();
    if (!mounted) return;
    setState(() => _listening = false);
    if (t.trim().isEmpty) return;
    await widget.onSubmit(text: null, transcript: t.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            autofocus: widget.autofocus,
            enabled: widget.enabled,
            decoration: InputDecoration(
              hintText: widget.hint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              isDense: true,
            ),
            onSubmitted: (_) => _sendText(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: widget.enabled ? _toggleMic : null,
          icon: Icon(_listening ? Icons.stop_circle : Icons.mic),
          tooltip: _listening ? 'Stop' : 'Mic',
        ),
        IconButton(
          onPressed: widget.enabled ? _sendText : null,
          icon: const Icon(Icons.send),
          tooltip: 'Send',
        ),
      ],
    );
  }
}
