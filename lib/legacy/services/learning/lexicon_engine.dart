import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LexiconEntry {
  String phrase;
  int frequency;
  String intentBias;
  double confidence;
  DateTime lastUsed;

  LexiconEntry({
    required this.phrase,
    required this.frequency,
    required this.intentBias,
    required this.confidence,
    required this.lastUsed,
  });

  Map<String, dynamic> toJson() => {
        'phrase': phrase,
        'frequency': frequency,
        'intentBias': intentBias,
        'confidence': confidence,
        'lastUsed': lastUsed.toIso8601String(),
      };

  factory LexiconEntry.fromJson(Map<String, dynamic> json) {
    return LexiconEntry(
      phrase: json['phrase'],
      frequency: json['frequency'],
      intentBias: json['intentBias'],
      confidence: json['confidence'],
      lastUsed: DateTime.parse(json['lastUsed']),
    );
  }
}

class LexiconEngine {
  late File _file;
  final Map<String, LexiconEntry> _entries = {};

  int get entryCount => _entries.length;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/user_lexicon.json');

    if (await _file.exists()) {
      final raw = await _file.readAsString();
      if (raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        for (var e in decoded) {
          final entry = LexiconEntry.fromJson(e);
          _entries[entry.phrase] = entry;
        }
      }
    }
  }

  Future<void> processText(String text) async {
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(' ')
        .where((w) => w.length > 3);

    for (final w in words) {
      final existing = _entries[w];

      if (existing == null) {
        _entries[w] = LexiconEntry(
          phrase: w,
          frequency: 1,
          intentBias: _inferIntent(w),
          confidence: 0.1,
          lastUsed: DateTime.now(),
        );
      } else {
        existing.frequency += 1;
        existing.confidence =
            (existing.confidence + 0.05).clamp(0.0, 1.0);
        existing.lastUsed = DateTime.now();
      }
    }

    await _persist();
  }

  String _inferIntent(String word) {
    if (['buy', 'pickup', 'milk', 'eggs'].contains(word)) {
      return 'grocery';
    }
    if (['send', 'call', 'email'].contains(word)) {
      return 'action';
    }
    return 'informational';
  }

  Future<void> _persist() async {
    final data = _entries.values.map((e) => e.toJson()).toList();
    await _file.writeAsString(jsonEncode(data));
  }
}
