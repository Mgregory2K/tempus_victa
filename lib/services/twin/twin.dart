// Minimal Twin+ learning layer prototype
import 'dart:convert';

class TwinSignal {
  final String signalId;
  final String signalType; // click|accept|reject|snooze|modify|complete
  final String? itemId;
  final Map<String, dynamic> features;
  final DateTime timestamp;

  TwinSignal({
    required this.signalId,
    required this.signalType,
    this.itemId,
    Map<String, dynamic>? features,
    DateTime? timestamp,
  })  : features = features ?? {},
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'signal_id': signalId,
        'signal_type': signalType,
        'item_id': itemId,
        'features': features,
        'timestamp': timestamp.toIso8601String(),
      };
}

class TwinModel {
  final Map<String, double> _weights = {};
  final List<TwinSignal> _log = [];
  double learningRate;

  TwinModel({this.learningRate = 0.1});

  double getWeight(String key) => _weights[key] ?? 0.0;

  void setWeight(String key, double value) => _weights[key] = value;

  /// Update a weight by a delta (with learning rate applied). Returns new weight.
  double updateWeight(String key, double delta) {
    final before = getWeight(key);
    final after = before + delta * learningRate;
    _weights[key] = after;
    return after;
  }

  /// Process a signal and optionally update related weights using simple heuristics.
  void processSignal(TwinSignal s) {
    _log.add(s);
    // Simple mapping: signalType can map to weight keys
    final k = 'signal:${s.signalType}';
    double delta;
    switch (s.signalType) {
      case 'accept':
        delta = 1.0;
        break;
      case 'reject':
        delta = -1.0;
        break;
      case 'click':
        delta = 0.2;
        break;
      case 'complete':
        delta = 0.8;
        break;
      case 'snooze':
        delta = -0.2;
        break;
      default:
        delta = 0.0;
    }
    if (delta != 0.0) updateWeight(k, delta);
    // Example feature-based update: if features contain priority=urgent, bump priority weight
    if (s.features['priority'] == 'urgent') {
      updateWeight('feature:priority:urgent', 0.5);
    }
  }

  /// Export compact model
  String toJson() {
    final out = {'weights': _weights, 'log_count': _log.length};
    return jsonEncode(out);
  }

  /// Load weights from JSON (overwrites current weights)
  void loadFromJson(String jsonStr) {
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    final w = data['weights'] as Map<String, dynamic>?;
    if (w != null) {
      _weights.clear();
      w.forEach((k, v) => _weights[k] = (v as num).toDouble());
    }
  }

  List<TwinSignal> get log => List.unmodifiable(_log);
}
