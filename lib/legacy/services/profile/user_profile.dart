class TrustSignal {
  final String key; // domain:<host> | person:<name> | phone:<e164>
  double trust; // 0..1
  double confidence; // 0..1
  int samples;

  TrustSignal({
    required this.key,
    required this.trust,
    required this.confidence,
    required this.samples,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'trust': trust,
        'confidence': confidence,
        'samples': samples,
      };

  static TrustSignal fromJson(Map<String, dynamic> j) => TrustSignal(
        key: (j['key'] ?? '').toString(),
        trust: _clamp01(_toDouble(j['trust']) ?? 0.55),
        confidence: _clamp01(_toDouble(j['confidence']) ?? 0.20),
        samples: (j['samples'] is int)
            ? (j['samples'] as int)
            : int.tryParse('${j['samples']}') ?? 0,
      );

  static double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
  static double? _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }
}

class UserPreferences {
  // Cost-aware defaults
  bool aiDefaultOff = true;

  // Response preference defaults
  bool preferShortCorrect = true;

  // Default routing behavior
  bool allowWebByDefault = true;

  // Extra flags (expandable)
  Map<String, dynamic> extra = {};

  Map<String, dynamic> toJson() => {
        'aiDefaultOff': aiDefaultOff,
        'preferShortCorrect': preferShortCorrect,
        'allowWebByDefault': allowWebByDefault,
        'extra': extra,
      };

  static UserPreferences fromJson(Map<String, dynamic> j) {
    final p = UserPreferences();
    p.aiDefaultOff = (j['aiDefaultOff'] is bool) ? j['aiDefaultOff'] : true;
    p.preferShortCorrect = (j['preferShortCorrect'] is bool) ? j['preferShortCorrect'] : true;
    p.allowWebByDefault = (j['allowWebByDefault'] is bool) ? j['allowWebByDefault'] : true;
    p.extra = (j['extra'] is Map) ? Map<String, dynamic>.from(j['extra']) : {};
    return p;
  }
}

class UserProfile {
  // numeric personality dimensions (expandable)
  double directness = 0.75; // 0..1
  double skepticism = 0.70; // 0..1
  double verbosity = 0.25; // 0..1 (low = short answers)
  int interactions = 0;

  // trust registry
  final Map<String, TrustSignal> trustMap = {};

  // lightweight “learning trail”
  String? lastQuery;
  String? lastSource; // LOCAL / WEB / AI
  String? lastMode; // LOCAL / WEB / AI

  UserPreferences prefs = UserPreferences();

  Map<String, dynamic> toJson() => {
        'directness': directness,
        'skepticism': skepticism,
        'verbosity': verbosity,
        'interactions': interactions,
        'lastQuery': lastQuery,
        'lastSource': lastSource,
        'lastMode': lastMode,
        'prefs': prefs.toJson(),
        'trustMap': trustMap.map((k, v) => MapEntry(k, v.toJson())),
      };

  static UserProfile fromJson(Map<String, dynamic> j) {
    final p = UserProfile();
    p.directness = _clamp01(_toDouble(j['directness']) ?? p.directness);
    p.skepticism = _clamp01(_toDouble(j['skepticism']) ?? p.skepticism);
    p.verbosity = _clamp01(_toDouble(j['verbosity']) ?? p.verbosity);
    p.interactions = (j['interactions'] is int)
        ? j['interactions']
        : int.tryParse('${j['interactions']}') ?? 0;

    p.lastQuery = (j['lastQuery'] ?? '').toString().trim().isEmpty ? null : (j['lastQuery']).toString();
    p.lastSource = (j['lastSource'] ?? '').toString().trim().isEmpty ? null : (j['lastSource']).toString();
    p.lastMode = (j['lastMode'] ?? '').toString().trim().isEmpty ? null : (j['lastMode']).toString();

    if (j['prefs'] is Map) {
      p.prefs = UserPreferences.fromJson(Map<String, dynamic>.from(j['prefs']));
    }

    final tm = j['trustMap'];
    if (tm is Map) {
      for (final e in tm.entries) {
        final k = e.key.toString();
        final v = e.value;
        if (v is Map) {
          p.trustMap[k] = TrustSignal.fromJson(Map<String, dynamic>.from(v));
        }
      }
    }
    return p;
  }

  static double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
  static double? _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }
}
