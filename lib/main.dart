import 'package:flutter/material.dart';

import 'ui/root_shell.dart';
import 'ui/theme/tempus_theme.dart';

void main() {
  runApp(const TempusApp());
}

class TempusApp extends StatelessWidget {
  const TempusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tempus, Victa',
      debugShowCheckedModeBanner: false,
      theme: TempusTheme.light(),
      darkTheme: TempusTheme.dark(),
      themeMode: ThemeMode.system,
      home: const RootShell(),
    );
  }
}
