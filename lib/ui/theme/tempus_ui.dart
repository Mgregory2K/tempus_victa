import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'tempus_theme.dart';

class TempusCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool elevated;
  const TempusCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final b = context.tv;
    final bg = elevated ? b.surface2 : b.surface1;

    final card = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(b.radiusLg),
        border: Border.all(color: b.border.withOpacity(.9)),
        boxShadow: [
          // soft, professional shadow (not Material default)
          BoxShadow(
            blurRadius: elevated ? 18 : 10,
            spreadRadius: 0,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? .28 : .08),
          ),
          // subtle inner highlight
          BoxShadow(
            blurRadius: 0,
            spreadRadius: 1,
            offset: const Offset(0, 0),
            color: Colors.white.withOpacity(Theme.of(context).brightness == Brightness.dark ? .03 : .45),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return card;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(b.radiusLg),
      child: card,
    );
  }
}

class TempusMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  const TempusMetricTile({super.key, required this.label, required this.value, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final b = context.tv;

    return TempusCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: b.accent.withOpacity(Theme.of(context).brightness == Brightness.dark ? .12 : .10),
              border: Border.all(color: b.accent.withOpacity(.35)),
            ),
            child: Icon(icon, size: 18, color: b.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          if (onTap != null) Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}

class TempusPill extends StatelessWidget {
  final String text;
  final Color? color;
  final VoidCallback? onTap;
  const TempusPill({super.key, required this.text, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = context.tv;
    final c = color ?? b.border;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: c.withOpacity(Theme.of(context).brightness == Brightness.dark ? .18 : .12),
        border: Border.all(color: c.withOpacity(.55)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
    return onTap == null ? pill : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(999), child: pill);
  }
}

class TempusBackground extends StatelessWidget {
  final Widget child;
  const TempusBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final b = context.tv;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // base fill
        Positioned.fill(child: ColoredBox(color: b.surface0)),

        // top radial glow (professional, subtle)
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.8, -1.0),
                  radius: 1.2,
                  colors: [
                    b.accent.withOpacity(isDark ? .10 : .08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // diagonal wash for texture
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primary.withOpacity(isDark ? .06 : .05),
                    Colors.transparent,
                    cs.primary.withOpacity(isDark ? .04 : .03),
                  ],
                ),
              ),
            ),
          ),
        ),

        // faint noise/dots
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _NoisePainter(isDark: isDark, color: cs.onSurface.withOpacity(isDark ? .05 : .035))),
          ),
        ),

        // content
        Positioned.fill(child: child),
      ],
    );
  }
}

class _NoisePainter extends CustomPainter {
  final bool isDark;
  final Color color;
  _NoisePainter({required this.isDark, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final rng = math.Random(1337);
    // a few hundred dots; cheap
    for (int i = 0; i < 420; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = (rng.nextDouble() * 0.8) + 0.2;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) => false;
}
