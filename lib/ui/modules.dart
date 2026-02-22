import 'package:flutter/material.dart';

class ModuleDef {
  final String name;
  final IconData icon;

  const ModuleDef(this.name, this.icon);
}

const List<ModuleDef> kPrimaryModules = [
  ModuleDef('Bridge', Icons.dashboard_rounded),
  ModuleDef('Signal Bay', Icons.radar_rounded),
  ModuleDef('Corkboard', Icons.note_alt_rounded),
  ModuleDef('Tasks', Icons.checklist_rounded),
  ModuleDef('Projects', Icons.folder_rounded),
  ModuleDef('Ready Room', Icons.meeting_room_rounded),
  ModuleDef('Quote Board', Icons.format_quote_rounded),
  ModuleDef('Recycle Bin', Icons.delete_rounded),
  ModuleDef('Settings', Icons.settings_rounded),
  ModuleDef('Lists', Icons.list_alt_rounded),
  ModuleDef('TBD', Icons.extension_rounded),
];