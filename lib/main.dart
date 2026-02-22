// Tempus Vista rebuild - generated 2026-02-21
// Local-first, Android-first.


import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/tempus_app.dart';

/// App entry.
///
/// Stabilization notes:
/// - Wrap startup in a guarded zone so any async boot exception doesn't
///   hard-crash the process (which breaks the Dart VM service connection).
/// - Route Flutter framework errors into the same zone handler.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    Zone.current.handleUncaughtError(
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };

  runZonedGuarded(() {
    runApp(const TempusApp());
  }, (Object error, StackTrace stack) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('UNCAUGHT: $error\n$stack');
    }
  });
}
