import 'package:flutter/foundation.dart';

/// A lightweight, local-only suggestion surfaced by Doctrine/Twin+.
///
/// Suggestions are *advisory* and must never break core flows.
/// They should be dismissible and throttleable.
@immutable
class Suggestion {
  final String id;
  final String title;
  final String body;
  final String? target; // optional room/action hint
  final double confidence; // 0.0 - 1.0
  final DateTime createdAt;

  const Suggestion({
    required this.id,
    required this.title,
    required this.body,
    required this.confidence,
    required this.createdAt,
    this.target,
  });
}
