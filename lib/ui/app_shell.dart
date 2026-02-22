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
  // In-memory module order (later: persist to local storage)
  List<ModuleDef> _modules = List<ModuleDef>.from(kPrimaryModules);

  // Track selection by ID so reorder does not “change” your current room.
  String _selectedModuleId = kPrimaryModules.first.id;

  bool get _carouselEnabled => true;

  int get _selectedIndex {
    final idx = _modules.indexWhere((m) => m.id == _selectedModuleId);
    return idx >= 0 ? idx : 0;
  }

  void _selectByIndex(int idx) {
    if (idx < 0 || idx >= _modules.length) return;
    setState(() {
      _selectedModuleId = _modules[idx].id;
    });
  }

  Future<void> _openReorderSheet() async {
    // Make a working copy for the modal.
    var working = List<ModuleDef>.from(_modules);

    final result = await showModalBottomSheet<List<ModuleDef>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Edit Carousel',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              working = List<ModuleDef>.from(kPrimaryModules);
                            });
                          },
                          child: const Text('Reset'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, working),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Drag to reorder. This won’t happen accidentally — you must long-press the centered icon to get here.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.65,
                      ),
                      child: ReorderableListView.builder(
                        itemCount: working.length,
                        onReorder: (oldIndex, newIndex) {
                          setModalState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = working.removeAt(oldIndex);
                            working.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, i) {
                          final m = working[i];
                          return ListTile(
                            key: ValueKey(m.id),
                            leading: Icon(m.icon),
                            title: Text(m.name),
                            trailing: const Icon(Icons.drag_handle_rounded),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (result == null) return;

    setState(() {
      _modules = result;

      // Keep the same selected room by ID after reorder.
      if (_modules.indexWhere((m) => m.id == _selectedModuleId) < 0) {
        _selectedModuleId = _modules.first.id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _modules
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
                key: ValueKey(_modules.map((m) => m.id).join('|')),
                modules: _modules,
                selectedIndex: _selectedIndex,
                onSelect: _selectByIndex,
                onRequestReorder: _openReorderSheet,
              ),
            )
          : null,
    );
  }
}