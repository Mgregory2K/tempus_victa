// Tempus Victa - bottom navigation (module ring)
//
// UX:
// - The module list "rotates" around the bottom (swipeable carousel).
// - Keeps primary modules fast, but feels alive (not static).
// - Nav does NOT live in RootShell (per directive); it's rendered by TempusScaffold.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile/ui/tempus_nav.dart';

class TempusCarouselNav extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const TempusCarouselNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  State<TempusCarouselNav> createState() => _TempusCarouselNavState();
}

class _TempusCarouselNavState extends State<TempusCarouselNav> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      viewportFraction: 0.36,
      initialPage: widget.selectedIndex.clamp(0, primaryNavItems.length - 1),
    );
  }

  @override
  void didUpdateWidget(covariant TempusCarouselNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.selectedIndex.clamp(0, primaryNavItems.length - 1);
    if (oldWidget.selectedIndex != target && _controller.hasClients) {
      _controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final current = widget.selectedIndex.clamp(0, primaryNavItems.length - 1);

    return Material(
      elevation: 10,
      color: cs.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: PageView.builder(
            controller: _controller,
            itemCount: primaryNavItems.length,
            onPageChanged: (i) => widget.onTap(i),
            itemBuilder: (context, i) {
              final item = primaryNavItems[i];
              final selected = i == current;

              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  double t = 1.0;
                  if (_controller.hasClients && _controller.position.haveDimensions) {
                    final page = _controller.page ?? _controller.initialPage.toDouble();
                    final dist = (page - i).abs().clamp(0.0, 1.0);
                    t = 1.0 - dist;
                  }
                  final scale = 0.86 + (t * 0.18);
                  final opacity = 0.55 + (t * 0.45);

                  return Center(
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: _NavChip(
                          icon: item.icon,
                          label: item.label,
                          selected: selected,
                          onTap: () => widget.onTap(i),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected ? cs.primaryContainer : cs.surfaceVariant;
    final fg = selected ? cs.onPrimaryContainer : cs.onSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
