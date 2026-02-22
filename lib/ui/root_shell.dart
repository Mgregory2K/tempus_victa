// Tempus Victa - Root Shell
//
// IMPORTANT: Nav bar does NOT live in RootShell by design.
// RootShell only swaps pages; each page renders its own persistent nav (SafeArea aware).

import 'package:flutter/material.dart';

import '../features/actions/actions_screen.dart';
import '../features/bridge/bridge_screen.dart';
import '../features/corkboard/corkboard_screen.dart';
import '../features/lists/lists_screen.dart';
import '../features/projects/projects_screen.dart';
import '../features/recycle/recycle_screen.dart';
import '../features/ready_room/ready_room_screen.dart';
import '../features/review/review_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/signals/signals_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _selectedIndex = 0;

  void _setIndex(int i) => setState(() => _selectedIndex = i);

  @override
  Widget build(BuildContext context) {
    // Keep this list aligned with ui/tempus_nav.dart tempusNavItems order.
    final pages = <Widget>[
      // Primary tabs (concept PNGs)
      BridgeScreen(onNavigate: _setIndex, selectedIndex: _selectedIndex), // 0 Today
      ProjectsScreen(onNavigate: _setIndex, selectedIndex: _selectedIndex), // 1 Projects
      ListsScreen(onNavigate: _setIndex, selectedIndex: _selectedIndex), // 2 Lists
      ReviewScreen(onNavigate: _setIndex, selectedIndex: _selectedIndex), // 3 Review

      // Secondary modules (More)
      SignalsScreen(onNavigate: _setIndex, selectedIndex: _selectedIndex), // 4 Signal Bay
      ActionsScreen(onNavigate: _setIndex, selectedIndex: _selectedIndex), // 5 Actions
      CorkboardScreen(onNavigate: _setIndex, selectedIndex: _selectedIndex), // 6 Corkboard
      RecycleScreen(onNavigate: _setIndex, selectedIndex: _selectedIndex), // 7 Recycle
      ReadyRoomScreen(onNavigate: _setIndex, selectedIndex: _selectedIndex), // 8 Ready Room
      SettingsScreen(onNavigate: _setIndex, selectedIndex: _selectedIndex), // 9 Settings
    ];

    final idx = _selectedIndex.clamp(0, pages.length - 1);
    return pages[idx];
  }
}
