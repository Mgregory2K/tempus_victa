import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/device_signals_service.dart';
import '../core/twin_plus/twin_plus_kernel.dart';

import '../core/app_state_scope.dart';
import '../core/module_def.dart';
import '../core/module_order_store.dart';
import '../core/module_registry.dart';
import 'gear_carousel_nav.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  late final AppState _appState;

  List<ModuleDef> _modules = [];
  String _selectedModuleId = 'bridge';

  int get _selectedIndex {
    final idx = _modules.indexWhere((m) => m.id == _selectedModuleId);
    return idx >= 0 ? idx : 0;
  }

  @override
  void initState() {
    super.initState();
    DeviceSignalsService.instance.start(kernel: TwinPlusKernel.instance);
    _modules = ModuleRegistry.defaultModules();
    _appState = AppState(
      selectedModuleId: _selectedModuleId,
      moduleOrderIds: _modules.map((m) => m.id).toList(),
    );
    _restoreModuleOrder();
  }

  Future<void> _restoreModuleOrder() async {
    final savedIds = await ModuleOrderStore.loadOrderIds();
    if (!mounted) return;

    if (savedIds == null) return;

    final defaults = ModuleRegistry.defaultModules();
    final byId = {for (final m in defaults) m.id: m};

    final restored = <ModuleDef>[];
    for (final id in savedIds) {
      final m = byId[id];
      if (m != null) restored.add(m);
    }
    for (final m in defaults) {
      if (!restored.any((x) => x.id == m.id)) restored.add(m);
    }

    setState(() { _modules = restored; _appState.moduleOrderIds = _modules.map((m) => m.id).toList(growable: false); });
  }

  Future<void> _persistModuleOrder() async {
    await ModuleOrderStore.saveOrderIds(_modules.map((m) => m.id).toList());
  }

  Future<void> _openReorderSheet() async {
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
                              working = ModuleRegistry.defaultModules();
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
      _appState.moduleOrderIds = _modules.map((m) => m.id).toList(growable: false);
      if (_modules.indexWhere((m) => m.id == _selectedModuleId) < 0) {
        _selectedModuleId = _modules.first.id;
        _appState.setSelectedModule(_selectedModuleId);
      }
    });

    await _persistModuleOrder();
  }

  void _selectByIndex(int idx) {
    if (idx < 0 || idx >= _modules.length) return;
    setState(() { _selectedModuleId = _modules[idx].id; _appState.setSelectedModule(_selectedModuleId); });
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _modules.map((m) => m.builder(roomName: m.name)).toList();

    return AppStateScope(
      appState: _appState,
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: rooms,
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: GearCarouselNav(
            key: ValueKey(_modules.map((m) => m.id).join('|')),
            modules: _modules,
            selectedIndex: _selectedIndex,
            onSelect: _selectByIndex,
            onRequestReorder: _openReorderSheet,
          ),
        ),
      ),
    );
  }
}
