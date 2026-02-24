import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class TwinPreferenceLedger {
  final File _file;
  Map<String, dynamic> _state;

  static const String _kDownvoteDetailThreshold = 'downvoteDetailThreshold';
  static const String _kDownvoteDetailCount = 'downvoteDetailCount';

  TwinPreferenceLedger._(this._file, this._state);

  static Future<TwinPreferenceLedger> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final tp = Directory(p.join(dir.path, 'twin_plus'));
    if (!tp.existsSync()) tp.createSync(recursive: true);
    final f = File(p.join(tp.path, 'preferences.json'));
    Map<String, dynamic> state = <String, dynamic>{};
    if (f.existsSync()) {
      try {
        final raw = await f.readAsString();
        final j = jsonDecode(raw);
        if (j is Map<String, dynamic>) state = j;
      } catch (_) {}
    } else {
      await f.writeAsString(jsonEncode(_defaults()), flush: true);
      state = _defaults();
    }
    state = {..._defaults(), ...state};
    return TwinPreferenceLedger._(f, state);
  }

  static Map<String, dynamic> _defaults() => <String, dynamic>{
        'lengthDefault': 'normal', // tiny|short|normal|long
        'toneDefault': 'neutral', // neutral|blunt|exploratory|supportive|sarcastic
        'formatDefault': 'bullets', // bullets|steps|narrative
        'hatesVerbose': 0.0, // 0..1
        'hatesClarifyingQuestions': 0.0,
        'hatesStaleInfo': 0.0,
        'justTheFactsActive': false,
        'dailyTokenCap': 15000,
        'aiOptIn': false, // mirrors AiSettingsStore but gives Twin+ a fast read
        _kDownvoteDetailThreshold: 25,
        _kDownvoteDetailCount: 0,
      };

  Future<void> persist() async {
    await _file.writeAsString(jsonEncode(_state), flush: true);
  }

  Map<String, dynamic> snapshot() => Map<String, dynamic>.from(_state);

  String get lengthDefault => (_state['lengthDefault'] ?? 'normal').toString();
  String get toneDefault => (_state['toneDefault'] ?? 'neutral').toString();
  String get formatDefault => (_state['formatDefault'] ?? 'bullets').toString();

  bool get justTheFactsActive => (_state['justTheFactsActive'] ?? false) == true;

  /// How many times we should prompt for downvote details ("Wrong source", etc.)
  /// before switching to plain thumbs-only behavior.
  int get downvoteDetailThreshold => (_state[_kDownvoteDetailThreshold] is int)
      ? (_state[_kDownvoteDetailThreshold] as int)
      : int.tryParse('${_state[_kDownvoteDetailThreshold]}') ?? 25;

  /// Count of how many times we have shown the downvote-details prompt.
  int get downvoteDetailCount => (_state[_kDownvoteDetailCount] is int)
      ? (_state[_kDownvoteDetailCount] as int)
      : int.tryParse('${_state[_kDownvoteDetailCount]}') ?? 0;

  double get hatesVerbose => _asDouble(_state['hatesVerbose']);
  double get hatesClarifyingQuestions => _asDouble(_state['hatesClarifyingQuestions']);
  double get hatesStaleInfo => _asDouble(_state['hatesStaleInfo']);

  int get dailyTokenCap => (_state['dailyTokenCap'] is int) ? (_state['dailyTokenCap'] as int) : 15000;

  bool get aiOptIn => (_state['aiOptIn'] ?? false) == true;

  Future<void> setAiOptIn(bool v) async {
    _state['aiOptIn'] = v;
    await persist();
  }

  Future<void> setJustTheFacts(bool v) async {
    _state['justTheFactsActive'] = v;
    await persist();
  }

  Future<void> setDownvoteDetailThreshold(int v) async {
    _state[_kDownvoteDetailThreshold] = v < 0 ? 0 : v;
    await persist();
  }

  Future<void> incDownvoteDetailCount() async {
    _state[_kDownvoteDetailCount] = downvoteDetailCount + 1;
    await persist();
  }

  Future<void> reinforceVerboseComplaint() async {
    _state['hatesVerbose'] = _clamp01(hatesVerbose + 0.12);
    if (hatesVerbose >= 0.35 && lengthDefault != 'short' && lengthDefault != 'tiny') {
      _state['lengthDefault'] = 'short';
    }
    await persist();
  }

  Future<void> reinforceStaleComplaint() async {
    _state['hatesStaleInfo'] = _clamp01(hatesStaleInfo + 0.12);
    await persist();
  }

  Future<void> reinforceClarificationComplaint() async {
    _state['hatesClarifyingQuestions'] = _clamp01(hatesClarifyingQuestions + 0.12);
    await persist();
  }

  static double _asDouble(dynamic v) => (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
  static double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
}
