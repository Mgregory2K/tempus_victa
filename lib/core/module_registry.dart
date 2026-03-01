import 'package:flutter/material.dart';

import 'module_def.dart';

import '../ui/rooms/bridge_room.dart';
import '../ui/rooms/daily_brief_room.dart';
import '../ui/rooms/signal_bay_room.dart';
import '../ui/rooms/tasks_room.dart';
import '../ui/rooms/projects_room.dart';
import '../ui/rooms/recycle_bin_room.dart';
import '../ui/rooms/ready_room.dart';
import '../ui/rooms/settings_room.dart';
import '../ui/rooms/corkboard_room.dart';
import '../ui/rooms/analyze_room.dart';
import '../ui/rooms/global_search_room.dart';
import '../ui/rooms/quote_board_room.dart';
import '../ui/rooms/lists_room.dart';
import '../ui/ask_user/ask_user_screen.dart';
import '../services/ask_user/ask_user.dart';
import '../services/router/router_service.dart';
import '../ui/drafts/drafts_screen.dart';

class ModuleRegistry {
  /// Default module list (used to seed first-run and as a reset fallback).
  ///
  /// NOTE: ModuleDef.builder signature is:
  ///   Widget Function({required String roomName})
  /// Many rooms in this codebase use the standard `({Key? key})` constructor,
  /// so we wrap them here and simply pass roomName where supported.
  static List<ModuleDef> defaultModules() => [
        ModuleDef(
          id: 'bridge',
          name: 'Bridge',
          icon: Icons.dashboard_rounded,
          usesCarousel: true,
          builder: ({required roomName}) => BridgeRoom(roomName: roomName),
        ),
        ModuleDef(
          id: 'daily_brief',
          name: 'Daily Brief',
          icon: Icons.summarize_rounded,
          usesCarousel: true,
          builder: ({required roomName}) => DailyBriefRoom(roomName: roomName),
        ),
        ModuleDef(
          id: 'signal_bay',
          name: 'Signal Bay',
          icon: Icons.radar_rounded,
          usesCarousel: true,
          builder: ({required roomName}) => SignalBayRoom(roomName: roomName),
        ),
        ModuleDef(
          id: 'global_search',
          name: 'Search',
          icon: Icons.search_rounded,
          usesCarousel: true,
          builder: ({required roomName}) =>
              GlobalSearchRoom(roomName: roomName),
        ),
        ModuleDef(
          id: 'corkboard',
          name: 'Corkboard',
          icon: Icons.note_alt_rounded,
          usesCarousel: true,
          builder: ({required roomName}) => CorkboardRoom(roomName: roomName),
        ),
        ModuleDef(
          id: 'tasks',
          name: 'Tasks',
          icon: Icons.checklist_rounded,
          usesCarousel: true,
          builder: ({required roomName}) => TasksRoom(roomName: roomName),
        ),
        ModuleDef(
          id: 'projects',
          name: 'Projects',
          icon: Icons.folder_rounded,
          usesCarousel: true,
          builder: ({required roomName}) => ProjectsRoom(roomName: roomName),
        ),
        ModuleDef(
          id: 'ready_room',
          name: 'Ready Room',
          icon: Icons.meeting_room_rounded,
          usesCarousel: true,
          builder: ({required roomName}) => ReadyRoom(roomName: roomName),
        ),
        ModuleDef(
          id: 'quote_board',
          name: 'Quote Board',
          icon: Icons.format_quote_rounded,
          usesCarousel: true,
          builder: ({required roomName}) => QuoteBoardRoom(roomName: roomName),
        ),
        ModuleDef(
          id: 'recycle_bin',
          name: 'Recycle Bin',
          icon: Icons.delete_rounded,
          usesCarousel: true,
          builder: ({required roomName}) => RecycleBinRoom(roomName: roomName),
        ),
        ModuleDef(
          id: 'settings',
          name: 'Settings',
          icon: Icons.settings_rounded,
          usesCarousel: true,
          builder: ({required roomName}) => SettingsRoom(roomName: roomName),
        ),
        ModuleDef(
          id: 'lists',
          name: 'Lists',
          icon: Icons.checklist_rounded,
          usesCarousel: true,
          builder: ({required roomName}) => ListsRoom(roomName: roomName),
        ),
        ModuleDef(
          id: 'analyze',
          name: 'Analyze',
          icon: Icons.psychology_rounded,
          usesCarousel: true,
          builder: ({required roomName}) => AnalyzeRoom(roomName: roomName),
        ),
        ModuleDef(
          id: 'asks',
          name: 'Decisions',
          icon: Icons.help_outline_rounded,
          usesCarousel: true,
          builder: ({required roomName}) {
            final store = RouterService.instance.store!;
            final mgr = AskUserManager(store);
            return AskUserScreen(manager: mgr);
          },
        ),
        ModuleDef(
          id: 'drafts',
          name: 'Drafts',
          icon: Icons.drafts_rounded,
          usesCarousel: true,
          builder: ({required roomName}) => const DraftsScreen(),
        ),
      ];
}
