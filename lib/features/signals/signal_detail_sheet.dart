// Tempus Vista rebuild - generated 2026-02-21
// Local-first, Android-first.


import 'package:flutter/material.dart';

import '../../data/models/signal.dart';
import '../../ui/widgets/glass_card.dart';

class SignalDetailSheet extends StatelessWidget {
  final Signal signal;

  const SignalDetailSheet({super.key, required this.signal});

  @override
  Widget build(BuildContext context) {
    final text = (signal.kind == 'voice') ? (signal.transcript ?? '') : (signal.text ?? '');
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Signal Detail', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('ID: ${signal.id}'),
            Text('Kind: ${signal.kind}'),
            Text('Source: ${signal.source}'),
            Text('Status: ${signal.status}'),
            const SizedBox(height: 10),
            Text(text),
            const SizedBox(height: 10),
            Text('Captured (UTC): ${signal.capturedAtUtc.toIso8601String()}'),
          ],
        ),
      ),
    );
  }
}
