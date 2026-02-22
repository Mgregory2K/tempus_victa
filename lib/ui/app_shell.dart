import 'package:flutter/material.dart';
import 'modules.dart';
import 'room_screen.dart';
import 'gear_carousel_nav.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  // In the future, this will be disabled for immersive modes
  bool get _carouselEnabled => true;

  @override
  Widget build(BuildContext context) {
    final rooms = kPrimaryModules
        .map((m) => RoomScreen(roomName: m.name))
        .toList(growable: false);

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: rooms,
        ),
      ),
      bottomNavigationBar: _carouselEnabled
          ? SafeArea(
              top: false,
              child: GearCarouselNav(
                selectedIndex: _selectedIndex,
                onSelect: (idx) {
                  setState(() {
                    _selectedIndex = idx;
                  });
                },
              ),
            )
          : null,
    );
  }
}