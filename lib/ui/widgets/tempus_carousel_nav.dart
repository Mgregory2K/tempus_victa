// Tempus Victa - bottom navigation (concept-aligned)
//
// - Matches the 4-tab bottom nav shown in the concept PNGs
// - Provides a "More" drawer for secondary modules
// - Nav does NOT live in RootShell (per directive); it's rendered by TempusScaffold.

import 'package:flutter/material.dart';
import 'package:mobile/ui/tempus_nav.dart';

class TempusCarouselNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const TempusCarouselNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Primary tabs map directly to indices 0..3 in RootShell.
    final current = selectedIndex.clamp(0, 3);

    return Material(
      elevation: 10,
      color: cs.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < primaryNavItems.length; i++)
                Expanded(
                  child: _NavButton(
                    icon: primaryNavItems[i].icon,
                    label: primaryNavItems[i].label,
                    selected: i == current,
                    onPressed: () => onTap(i),
                  ),
                ),
              SizedBox(
                width: 72,
                child: IconButton(
                  tooltip: 'More',
                  onPressed: () => _showMore(context),
                  icon: const Icon(Icons.more_horiz),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMore(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Modules',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              for (final item in secondaryNavItems)
                ListTile(
                  leading: Icon(item.icon, color: cs.primary),
                  title: Text(item.label),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    // Secondary items start at index 4 in RootShell.
                    final idx = primaryNavItems.length + secondaryNavItems.indexOf(item);
                    onTap(idx);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = selected ? cs.primary : cs.onSurface.withOpacity(0.8);

    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
