import 'package:flutter/material.dart';

class ModuleDef {
  final String id;
  final String name;
  final IconData icon;

  const ModuleDef(this.id, this.name, this.icon);
}

const List<ModuleDef> kPrimaryModules = [
  ModuleDef('bridge', 'Bridge', Icons.dashboard_rounded),
  ModuleDef('signal_bay', 'Signal Bay', Icons.radar_rounded),
  ModuleDef('corkboard', 'Corkboard', Icons.note_alt_rounded),
  ModuleDef('tasks', 'Tasks', Icons.checklist_rounded),
  ModuleDef('projects', 'Projects', Icons.folder_rounded),
  ModuleDef('ready_room', 'Ready Room', Icons.meeting_room_rounded),
  ModuleDef('quote_board', 'Quote Board', Icons.format_quote_rounded),
  ModuleDef('recycle_bin', 'Recycle Bin', Icons.delete_rounded),
  ModuleDef('settings', 'Settings', Icons.settings_rounded),
  ModuleDef('lists', 'Lists', Icons.list_alt_rounded),
  ModuleDef('record', 'Record', Icons.record_voice_over),
];