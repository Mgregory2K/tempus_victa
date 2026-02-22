import 'package:flutter/material.dart';

import 'module_def.dart';
import '../ui/placeholder_room.dart';

import '../ui/rooms/bridge_room.dart';
import '../ui/rooms/signal_bay_room.dart';
import '../ui/rooms/tasks_room.dart';
import '../ui/rooms/projects_room.dart';
import '../ui/rooms/recycle_bin_room.dart';

class ModuleRegistry {
  static List<ModuleDef> defaultModules() => const [
        ModuleDef(
          id: 'bridge',
          name: 'Bridge',
          icon: Icons.dashboard_rounded,
          usesCarousel: true,
          builder: BridgeRoom.new,
        ),
        ModuleDef(
          id: 'signal_bay',
          name: 'Signal Bay',
          icon: Icons.radar_rounded,
          usesCarousel: true,
          builder: SignalBayRoom.new,
        ),
        ModuleDef(
          id: 'corkboard',
          name: 'Corkboard',
          icon: Icons.note_alt_rounded,
          usesCarousel: true,
          builder: PlaceholderRoom.new,
        ),
        ModuleDef(
          id: 'tasks',
          name: 'Tasks',
          icon: Icons.checklist_rounded,
          usesCarousel: true,
          builder: TasksRoom.new,
        ),
        ModuleDef(
          id: 'projects',
          name: 'Projects',
          icon: Icons.folder_rounded,
          usesCarousel: true,
          builder: ProjectsRoom.new,
        ),
        ModuleDef(
          id: 'ready_room',
          name: 'Ready Room',
          icon: Icons.meeting_room_rounded,
          usesCarousel: true,
          builder: PlaceholderRoom.new,
        ),
        ModuleDef(
          id: 'quote_board',
          name: 'Quote Board',
          icon: Icons.format_quote_rounded,
          usesCarousel: true,
          builder: PlaceholderRoom.new,
        ),
        ModuleDef(
          id: 'recycle_bin',
          name: 'Recycle Bin',
          icon: Icons.delete_rounded,
          usesCarousel: true,
          builder: RecycleBinRoom.new,
        ),
        ModuleDef(
          id: 'settings',
          name: 'Settings',
          icon: Icons.settings_rounded,
          usesCarousel: true,
          builder: PlaceholderRoom.new,
        ),
        ModuleDef(
          id: 'lists',
          name: 'Lists',
          icon: Icons.list_alt_rounded,
          usesCarousel: true,
          builder: PlaceholderRoom.new,
        ),
        ModuleDef(
          id: 'tbd',
          name: 'TBD',
          icon: Icons.extension_rounded,
          usesCarousel: true,
          builder: PlaceholderRoom.new,
        ),
      ];
}
