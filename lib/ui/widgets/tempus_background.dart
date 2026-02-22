// Tempus Victa rebuild - updated 2026-02-21
// Local-first, Android-first.

import 'package:flutter/material.dart';

class TempusBackground extends StatelessWidget {
  final Widget child;

  const TempusBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surface,
            cs.surfaceContainerHighest.withOpacity(0.35),
          ],
        ),
      ),
      child: child,
    );
  }
}
