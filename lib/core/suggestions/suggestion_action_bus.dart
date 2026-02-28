import 'package:flutter/foundation.dart';

/// ZIP 25 — lightweight in-app action bus for suggestion clicks.
/// This lets a banner trigger a concrete action inside a target room
/// (e.g., open voice capture) without tight coupling.
class SuggestionActionBus {
  SuggestionActionBus._();
  static final SuggestionActionBus instance = SuggestionActionBus._();

  final ValueNotifier<String?> actionId = ValueNotifier<String?>(null);

  void emit(String id) {
    actionId.value = id;
  }

  /// Consumers should call this after handling the action.
  void clear() {
    actionId.value = null;
  }
}
