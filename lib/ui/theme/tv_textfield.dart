import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Central defaults for all text input in Tempus, Victa:
/// - Autocorrect ON
/// - Suggestions ON
/// - Sentence capitalization
/// - Optional voice input (mic button) for driving-safety
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
  });

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  final _stt = stt.SpeechToText();
  bool _sttReady = false;
  bool _listening = false;

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
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
        suffixIcon: suffix,
      ),
    );
  }
}
