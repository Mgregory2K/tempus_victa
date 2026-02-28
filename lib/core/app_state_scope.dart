import 'package:flutter/widgets.dart';
import 'app_state.dart';

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState appState,
    required super.child,
  }) : super(notifier: appState);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    if (scope == null) {
      throw StateError('AppStateScope not found in widget tree.');
    }
    final n = scope.notifier;
    if (n == null) throw StateError('AppStateScope notifier is null.');
    return n;
  }
}
