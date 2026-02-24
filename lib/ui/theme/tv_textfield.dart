import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/twin_plus/twin_event.dart';
import '../../core/twin_plus/twin_plus_kernel.dart';

/// Central defaults for all text input in Tempus, Victa:
/// - Autocorrect ON
/// - Suggestions ON
/// - Sentence capitalization
/// - Optional voice input (mic button) for driving-safety
///
/// Twin+ hooks:
/// - Provide [twinSurface] + [twinFieldId] to emit local TwinEvents
///   for text edits/submits. No network. No AI.
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
  final _stt = stt.SpeechToText();
  bool _sttReady = false;
  bool _listening = false;

  DateTime _lastEditEmit = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    if (widget.enableVoice && widget.suffixIcon == null) {
      _initStt();
    }
  }

  Future<void> _initStt() async {
    try {
      final ok = await _stt.initialize();
      if (!mounted) return;
      setState(() => _sttReady = ok);
    } catch (_) {
      // If STT isn't available on device/emulator, fail silent.
      if (!mounted) return;
      setState(() => _sttReady = false);
    }
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
    final words = v.trim().isEmpty ? 0 : v.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final hasCaps = RegExp(r'[A-Z]{2,}').hasMatch(v);
    final lower = v.toLowerCase();
    final hasProfanity = lower.contains('fuck') || lower.contains('shit') || lower.contains('damn') || lower.contains('bastard');
    final punct = RegExp(r'[\,\.\!\?\:\;\-\(\)\[\]\{\}]').allMatches(v).length;
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
    final words = txt.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final hasCaps = RegExp(r'[A-Z]{2,}').hasMatch(txt);
    final lower = txt.toLowerCase();
    final hasProfanity = lower.contains('fuck') || lower.contains('shit') || lower.contains('damn') || lower.contains('bastard');
    final punct = RegExp(r'[\,\.\!\?\:\;\-\(\)\[\]\{\}]').allMatches(txt).length;
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
    if (!_sttReady) return;

    if (_listening) {
      await _stt.stop();
      if (!mounted) return;
      setState(() => _listening = false);
      return;
    }

    setState(() => _listening = true);
    await _stt.listen(
      onResult: (res) {
        final txt = res.recognizedWords.trim();
        if (txt.isEmpty) return;
        widget.controller.text = txt;
        widget.controller.selection = TextSelection.collapsed(offset: txt.length);

        _emitEdit(txt);
        widget.onChanged?.call(txt);
      },
    );
  }

  @override
  void dispose() {
    _stt.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suffix = widget.suffixIcon ??
        (widget.enableVoice && _sttReady
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
