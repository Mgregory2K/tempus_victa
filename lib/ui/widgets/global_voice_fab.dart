import 'package:flutter/material.dart';

import '../../core/app_state_scope.dart';
import '../../core/twin_plus/twin_plus_kernel.dart';
import '../../core/capture_executor.dart';
import '../../services/voice/voice_service.dart';

/// Universal voice capture button.
///
/// HARD STABILIZATION NOTE:
/// - Gesture-based long-press handlers can be flaky across devices/overlays.
/// - This uses a deterministic tap-to-toggle contract:
///     Tap = start listening
///     Tap again = stop + route
///
/// This preserves "easy button" behavior and eliminates "does nothing" failures.
class GlobalVoiceFab extends StatefulWidget {
  const GlobalVoiceFab({super.key});

  @override
  State<GlobalVoiceFab> createState() => _GlobalVoiceFabState();
}

class _GlobalVoiceFabState extends State<GlobalVoiceFab> {
  bool _ready = false;
  bool _holding = false;
  String _live = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ok = await VoiceService.instance.init();
    if (!mounted) return;
    setState(() => _ready = ok);
  }

  Future<void> _toggle() async {
    if (!_ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice not ready.')),
      );
      return;
    }

    if (_holding) {
      await _end();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    if (_holding) return;

    setState(() {
      _holding = true;
      _live = '';
    });

    final started = await VoiceService.instance.start(
      onPartial: (p) {
        if (!mounted) return;
        setState(() => _live = p);
      },
    );

    if (!started && mounted) {
      setState(() => _holding = false);
      final err = VoiceService.instance.lastError;
      final st = VoiceService.instance.lastStatus;
      final msg = (err != null && err.trim().isNotEmpty)
          ? 'Voice failed to start. STT error: $err'
          : (st != null && st.trim().isNotEmpty)
              ? 'Voice failed to start. STT status: $st'
              : 'Voice failed to start.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listening… tap again to stop.')),
      );
    }
  }

  Future<void> _end() async {
    if (!_holding) return;

    final res = await VoiceService.instance.stop(finalTranscript: _live);
    if (!mounted) return;

    setState(() => _holding = false);

    final transcript = res.transcript.trim();
    if (transcript.isEmpty) {
      final err = VoiceService.instance.lastError;
      final st = VoiceService.instance.lastStatus;
      final msg = (err != null && err.trim().isNotEmpty)
          ? 'No speech detected. STT error: $err'
          : (st != null && st.trim().isNotEmpty)
              ? 'No speech detected. STT status: $st'
              : 'No speech detected.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    final kernel = TwinPlusKernel.instance;

    // Route + apply via the stabilized executor (atomic boundary).
    final result = await CaptureExecutor.instance.executeVoiceCapture(
      surface: 'global_mic',
      transcript: transcript,
      durationMs: res.durationMs,
      audioPath: res.audioPath,
      observe: kernel.observe,
    );

    if (!mounted) return;
    // Navigate to the module returned by executor (or keep current if null).
    final module = result.nextModule;
    if (module != null && module.trim().isNotEmpty) {
      AppStateScope.of(context).setSelectedModule(module);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FloatingActionButton(
        heroTag: 'global_mic_fab',
        onPressed: _toggle,
        child: Icon(_holding ? Icons.stop_circle_outlined : Icons.mic_none_rounded),
      ),
    );
  }
}
