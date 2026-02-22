// Tempus Victa - navigation model

import 'package:flutter/material.dart';

class TempusNavItem {
  final String key;
  final String label;
  final IconData icon;

  const TempusNavItem({
    required this.key,
    required this.label,
    required this.icon,
  });
}

/// Primary bottom tabs (matches the concept PNGs).
///
/// RootShell still contains additional modules; those are reachable via the
/// "More" menu.
const primaryNavItems = <TempusNavItem>[
  TempusNavItem(key: 'today', label: 'Today', icon: Icons.home),
  TempusNavItem(key: 'projects', label: 'Projects', icon: Icons.view_kanban),
  TempusNavItem(key: 'lists', label: 'Lists', icon: Icons.list_alt),
  TempusNavItem(key: 'review', label: 'Review', icon: Icons.analytics_outlined),
];

/// Secondary modules accessible via "More".
const secondaryNavItems = <TempusNavItem>[
  TempusNavItem(key: 'signals', label: 'Signal Bay', icon: Icons.inbox),
  TempusNavItem(key: 'actions', label: 'Actions', icon: Icons.check_circle),
  TempusNavItem(key: 'corkboard', label: 'Corkboard', icon: Icons.push_pin),
  TempusNavItem(key: 'recycle', label: 'Recycle', icon: Icons.delete_outline),
  TempusNavItem(key: 'ready_room', label: 'Ready Room', icon: Icons.forum),
  TempusNavItem(key: 'settings', label: 'Settings', icon: Icons.settings),
];

/// Canonical list in RootShell order.
/// Keep this aligned with RootShell.pages.
const tempusNavItems = <TempusNavItem>[
  ...primaryNavItems,
  ...secondaryNavItems,
];
