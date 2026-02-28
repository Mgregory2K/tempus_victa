import 'twin_feature_store.dart';
import 'twin_preference_ledger.dart';

class OutputIntent {
  final String surface;
  final String purpose; // inform|plan|summarize|rewrite|coach|warn
  final String? toneTarget; // neutral|blunt|exploratory|supportive|sarcastic
  final String? lengthTarget; // tiny|short|normal|long
  final String? formatTarget; // bullets|steps|narrative
  final List<String> constraints;
  final String draftText;

  const OutputIntent({
    required this.surface,
    required this.purpose,
    required this.draftText,
    this.toneTarget,
    this.lengthTarget,
    this.formatTarget,
    this.constraints = const <String>[],
  });
}

class ShapedOutput {
  final String text;
  final String appliedLength;
  final String appliedFormat;

  const ShapedOutput({
    required this.text,
    required this.appliedLength,
    required this.appliedFormat,
  });
}

class TwinShaper {
  final TwinPreferenceLedger prefs;
  final TwinFeatureStore features;

  TwinShaper({required this.prefs, required this.features});

  ShapedOutput shape(OutputIntent intent) {
    final justFacts = prefs.justTheFactsActive || intent.constraints.any((c) => c.toLowerCase().contains('just the facts'));
    final length = justFacts ? 'tiny' : (intent.lengthTarget ?? prefs.lengthDefault);
    final format = justFacts ? 'bullets' : (intent.formatTarget ?? prefs.formatDefault);

    var text = intent.draftText.trim();

    if (justFacts) {
      text = _bulletize(text);
      text = _trimToLength(text, 'tiny');
    } else {
      text = _applyFormat(text, format);
      text = _trimToLength(text, length);
    }

    return ShapedOutput(text: text, appliedLength: length, appliedFormat: format);
  }

  String _applyFormat(String text, String format) {
    if (format == 'narrative') return text;
    if (format == 'steps') return _stepify(text);
    return _bulletize(text);
  }

  String _bulletize(String text) {
    // If already looks like bullets, return.
    if (text.contains('\n• ') || text.startsWith('• ')) return text;
    // Split into sentences-ish.
    final parts = text.split(RegExp(r'(?<=[\.\!\?])\s+'));
    final clean = parts.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (clean.length <= 1) return text;
    return clean.map((s) => '• $s').join('\n');
  }

  String _stepify(String text) {
    if (RegExp(r'^\d+\)').hasMatch(text.trim())) return text;
    final parts = text.split(RegExp(r'(?<=[\.\!\?])\s+'));
    final clean = parts.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (clean.length <= 1) return text;
    var i = 1;
    return clean.map((s) => '${i++}) $s').join('\n');
  }

  String _trimToLength(String text, String length) {
    int maxChars = 1400;
    if (length == 'tiny') maxChars = 320;
    if (length == 'short') maxChars = 650;
    if (length == 'normal') maxChars = 1400;
    if (length == 'long') maxChars = 2800;

    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars).trimRight()}…';
  }
}
