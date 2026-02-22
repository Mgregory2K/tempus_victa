// lib/services/nav/nav_bus.dart
import 'package:flutter/foundation.dart';

/// Global, local-only navigation bus.
///
/// Why:
/// - Bridge must always be reachable from anywhere.
/// - Ready Room hides the carousel, so it needs a floating Bridge button.
/// - We keep the Navigator stack clean; this bus only controls the shell index.
class NavBus {
  static final ValueNotifier<int> index = ValueNotifier<int>(0);

  static void go(int i) => index.value = i;

  static void goBridge() => go(0);
}
