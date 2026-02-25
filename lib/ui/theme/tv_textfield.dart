import 'package:flutter/material.dart';

import '../../core/twin_plus/twin_event.dart';
import '../../core/twin_plus/twin_plus_kernel.dart';
import '../../services/voice/voice_capture_store.dart';
import '../../services/voice/voice_service.dart';

/// Central defaults for all text input in Tempus, Victa:
/// - Autocorrect ON
/// - Suggestions ON
/// - Sentence capitalization
/// - Optional voice input (mic button)
///
/// Twin+ hooks:
/// - Provide [twinSurface] + [twinFieldId] to emit local TwinEvents
///   for text edits/submits and voice captures. Local-only.
class TvTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hintText;
  final int? maxLines;
  final bool autofocus;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool enableVoice;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  final String? twinSurface;
  final String? twinFieldId;

  const TvTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.maxLines = 1,
    this.autofocus = false,
    this.prefixIcon,
    this.suffixIcon,
    this.enableVoice = true,
    this.onChanged,
    this.onSubmitted,
    this.twinSurface,
    this.twinFieldId,
  });

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  bool _voiceReady = false;
  bool _listening = false;

  DateTime _lastEditEmit = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    if (widget.enableVoice && widget.suffixIcon == null) {
      _initVoice();
    }
  }

  Future<void> _initVoice() async {
    final ok = await VoiceService.instance.init();
    if (!mounted) return;
    setState(() => _voiceReady = ok);
  }

  void _emitEdit(String text) {
    final surface = widget.twinSurface;
    final fieldId = widget.twinFieldId;
    if (surface == null || surface.isEmpty) return;
    if (fieldId == null || fieldId.isEmpty) return;

    // Throttle to avoid spamming on fast typing.
    final now = DateTime.now();
    if (now.difference(_lastEditEmit).inMilliseconds < 650) return;
    _lastEditEmit = now;

    final v = text;
    final chars = v.length;
    final words = v.trim().isEmpty
        ? 0
        : v.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final hasCaps = RegExp(r'[A-Z]{2,}').hasMatch(v);
    final lower = v.toLowerCase();
    final hasProfanity = lower.contains('fuck') ||
        lower.contains('shit') ||
        lower.contains('damn') ||
        lower.contains('bastard');
    final punct = RegExp(r'[\,\.\!\?\:\;\-\(\)\[\]\{\}]')
        .allMatches(v)
        .length;
    final punctDensity = chars == 0 ? 0.0 : punct / chars;

    TwinPlusKernel.instance.observe(
      TwinEvent.textEdited(
        surface: surface,
        fieldId: fieldId,
        chars: chars,
        words: words,
        hasCaps: hasCaps,
        hasProfanity: hasProfanity,
        punctuationDensity: punctDensity,
      ),
    );
  }

  void _emitSubmit(String text) {
    final surface = widget.twinSurface;
    final fieldId = widget.twinFieldId;
    if (surface == null || surface.isEmpty) return;
    if (fieldId == null || fieldId.isEmpty) return;

    final txt = text.trim();
    if (txt.isEmpty) return;

    final chars = txt.length;
    final words =
        txt.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final hasCaps = RegExp(r'[A-Z]{2,}').hasMatch(txt);
    final lower = txt.toLowerCase();
    final hasProfanity = lower.contains('fuck') ||
        lower.contains('shit') ||
        lower.contains('damn') ||
        lower.contains('bastard');
    final punct = RegExp(r'[\,\.\!\?\:\;\-\(\)\[\]\{\}]')
        .allMatches(txt)
        .length;
    final punctDensity = chars == 0 ? 0.0 : punct / chars;

    TwinPlusKernel.instance.observe(
      TwinEvent.textSubmitted(
        surface: surface,
        fieldId: fieldId,
        text: txt,
        chars: chars,
        words: words,
        hasCaps: hasCaps,
        hasProfanity: hasProfanity,
        punctuationDensity: punctDensity,
      ),
    );
  }

  Future<void> _toggleListen() async {
    if (!_voiceReady) return;

    if (_listening) {
      final res =
          await VoiceService.instance.stop(finalTranscript: widget.controller.text);
      if (!mounted) return;
      setState(() => _listening = false);

      if (res.transcript.isNotEmpty) {
        widget.controller.text = res.transcript;
        widget.controller.selection =
            TextSelection.collapsed(offset: res.transcript.length);
      }

      final surface = widget.twinSurface;
      final fieldId = widget.twinFieldId;
      if (surface != null &&
          surface.isNotEmpty &&
          fieldId != null &&
          fieldId.isNotEmpty) {
        // Store capture for the next entity-creation action.
        VoiceCaptureStore.set(surface: surface, fieldId: fieldId, result: res);

        // Emit Twin+ voice captured event.
        final words = res.transcript.trim().isEmpty
            ? 0
            : res.transcript
                .trim()
                .split(RegExp(r'\s+'))
                .where((w) => w.isNotEmpty)
                .length;
        TwinPlusKernel.instance.observe(
          TwinEvent.voiceCaptured(
            surface: surface,
            fieldId: fieldId,
            durationMs: res.durationMs,
            preview6: res.preview6,
            chars: res.transcript.length,
            words: words,
          ),
        );
      }

      return;
    }

    setState(() => _listening = true);
    await VoiceService.instance.start(
      onPartial: (txt) {
        final t = txt.trim();
        if (t.isEmpty) return;
        widget.controller.text = t;
        widget.controller.selection = TextSelection.collapsed(offset: t.length);

        _emitEdit(t);
        widget.onChanged?.call(t);
      },
    );
  }

  @override
  void dispose() {
    if (_listening) {
      VoiceService.instance.stop(finalTranscript: widget.controller.text);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suffix = widget.suffixIcon ??
        (widget.enableVoice && _voiceReady
            ? IconButton(
                tooltip: _listening ? 'Stop voice input' : 'Voice input',
                onPressed: _toggleListen,
                icon: Icon(_listening ? Icons.mic : Icons.mic_none),
              )
            : null);

    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      maxLines: widget.maxLines,
      autofocus: widget.autofocus,
      autocorrect: true,
      enableSuggestions: true,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (v) {
        _emitEdit(v);
        widget.onChanged?.call(v);
      },
      onSubmitted: (v) {
        _emitSubmit(v);
        widget.onSubmitted?.call(v);
      },
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
        suffixIcon: suffix,
      ),
    );
  }
}
