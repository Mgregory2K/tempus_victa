import 'package:flutter/material.dart';

/// Lightweight background wrapper used across rooms.
///
/// This is intentionally minimal so it can safely exist even if theming evolves.
class TempusBackground extends StatelessWidget {
  final Widget child;

  const TempusBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.surface,
            cs.surfaceVariant.withOpacity(0.35),
          ],
        ),
      ),
      child: child,
    );
  }
}
