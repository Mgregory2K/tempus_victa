// Tempus Victa rebuild - updated 2026-02-21
// Local-first, Android-first.

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/ingestion/ingestion_service.dart';
import '../services/automation/automation_engine.dart';
import '../services/logging/jsonl_logger.dart';
import '../ui/root_shell.dart';

class TempusApp extends StatefulWidget {
  const TempusApp({super.key});

  @override
  State<TempusApp> createState() => _TempusAppState();
}

class _TempusAppState extends State<TempusApp> {
  bool _booted = false;
  String _status = 'Initializing…';

  @override
  void initState() {
    super.initState();
    // Boot AFTER first frame so the app doesn't die before the VM service
    // attaches (common when plugins throw during early startup).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _boot();
    });
  }

  Future<void> _boot() async {
    try {
      setState(() => _status = 'Requesting core permissions…');

      // Stabilization: request only what we MUST have to run the core flows.
      // Requesting everything up-front can throw/kill the process on some
      // OEM builds if permissions aren't declared or are restricted.
      await [
        Permission.microphone,
        Permission.notification,
        Permission.location,
        Permission.locationAlways,
        Permission.locationWhenInUse,
        Permission.contacts,
        Permission.calendar,
        Permission.storage,
        Permission.phone,
        Permission.sms,
        Permission.activityRecognition,
        Permission.ignoreBatteryOptimizations,
      ].request();

      setState(() => _status = 'Starting ingestion…');
      try {
        await IngestionService.instance.start();
      } catch (e, st) {
        await JsonlLogger.instance.log('boot_ingestion_error', {
          'error': e.toString(),
          'stack': st.toString(),
        });
      }

      setState(() => _status = 'Starting autopilot…');
      try {
        // Start the autopilot loop (executes when confidence crosses threshold).
        await AutomationEngine.instance.start();
      } catch (e, st) {
        await JsonlLogger.instance.log('boot_automation_error', {
          'error': e.toString(),
          'stack': st.toString(),
        });
      }

      if (mounted) setState(() => _booted = true);
    } catch (e, st) {
      await JsonlLogger.instance.log('boot_fatal_error', {
        'error': e.toString(),
        'stack': st.toString(),
      });
      if (mounted) {
        setState(() {
          _status = 'Boot error. App started in safe mode.';
          _booted = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tempus Victa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: _booted ? const RootShell() : _BootScreen(status: _status),
    );
  }
}

class _BootScreen extends StatelessWidget {
  final String status;
  const _BootScreen({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.surface,
              cs.surfaceContainerHighest.withOpacity(0.4),
            ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt, size: 44, color: cs.primary),
                const SizedBox(height: 14),
                Text('Tempus Victa', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(status, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(0.8))),
                const SizedBox(height: 18),
                const SizedBox(
                  width: 220,
                  child: LinearProgressIndicator(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
