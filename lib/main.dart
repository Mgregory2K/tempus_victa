import 'package:flutter/material.dart';

import 'core/app_settings_store.dart';
import 'core/app_theme_controller.dart';
import 'core/twin_plus/twin_plus_kernel.dart';
import 'services/device/device_ingest_service.dart';
import 'services/router/router_service.dart';
import 'core/twin_plus/twin_plus_scope.dart';
import 'ui/root_shell.dart';
import 'ui/theme/tempus_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Run the app immediately to show UI, then initialize heavier
  // services asynchronously to avoid blocking startup on some devices.
  runApp(const TempusApp());

  // Fire-and-forget initializers; catch and log errors to avoid
  // unhandled rejections crashing the app during warm startup.
  TwinPlusKernel.instance.init().catchError((e, st) {
    // ignore: avoid_print
    print('TwinPlusKernel.init error: $e');
  });

  DeviceIngestService.instance.init().catchError((e, st) {
    // ignore: avoid_print
    print('DeviceIngestService.init error: $e');
  });

  RouterService.instance.init().catchError((e, st) {
    // ignore: avoid_print
    print('RouterService.init error: $e');
  });
}

class TempusApp extends StatefulWidget {
  const TempusApp({super.key});

  @override
  State<TempusApp> createState() => _TempusAppState();
}

class _TempusAppState extends State<TempusApp> {
  final _settings = AppSettingsStore();
  ThemeMode _themeMode = ThemeMode.dark; // Jen demo default
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final mode = await _settings.loadThemeMode();
    if (!mounted) return;
    setState(() {
      _themeMode = mode;
      _loaded = true;
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    // Persist first, then apply immediately.
    await _settings.setThemeMode(mode);
    if (!mounted) return;
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    // Avoid a flash of the wrong theme at startup.
    if (!_loaded) {
      return MaterialApp(
        builder: (context, child) {
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: child,
          );
        },
        title: 'Tempus, Victa',
        debugShowCheckedModeBanner: false,
        theme: TempusTheme.light(),
        darkTheme: TempusTheme.dark(),
        themeMode: _themeMode,
        home: const SizedBox.shrink(),
      );
    }

    return MaterialApp(
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child,
        );
      },
      title: 'Tempus, Victa',
      debugShowCheckedModeBanner: false,
      theme: TempusTheme.light(),
      darkTheme: TempusTheme.dark(),
      themeMode: _themeMode,
      home: AppThemeController(
        themeMode: _themeMode,
        setThemeMode: _setThemeMode,
        child: TwinPlusScope(
            kernel: TwinPlusKernel.instance, child: const RootShell()),
      ),
    );
  }
}

// Backwards-compatible simple app used by widget tests.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _counter = 0;

  void _increment() => setState(() => _counter++);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('MyApp Test')),
        body: Center(
            child: Text('$_counter',
                style: Theme.of(context).textTheme.headlineMedium)),
        floatingActionButton: FloatingActionButton(
          onPressed: _increment,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
