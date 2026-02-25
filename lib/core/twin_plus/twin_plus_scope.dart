import 'package:flutter/widgets.dart';

import 'twin_plus_kernel.dart';

class TwinPlusScope extends InheritedWidget {
  final TwinPlusKernel kernel;

  const TwinPlusScope({
    super.key,
    required this.kernel,
    required super.child,
  });

  static TwinPlusKernel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TwinPlusScope>();
    if (scope == null) {
      // Fall back to singleton to avoid crashes if a screen is not yet wired.
      return TwinPlusKernel.instance;
    }
    return scope.kernel;
  }


  /// Returns null if no scope is found. Useful for additive instrumentation in low-level widgets.
  static TwinPlusKernel? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TwinPlusScope>();
    return scope?.kernel;
  }

  @override
  bool updateShouldNotify(TwinPlusScope oldWidget) => identical(kernel, oldWidget.kernel) == false;
}
