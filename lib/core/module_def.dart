import 'package:flutter/material.dart';

typedef ModuleBuilder = Widget Function({required String roomName});

class ModuleDef {
  final String id; // stable ID (persisted)
  final String name; // display name
  final IconData icon;
  final bool usesCarousel; // false for immersive-only modules later
  final ModuleBuilder builder;

  const ModuleDef({
    required this.id,
    required this.name,
    required this.icon,
    required this.usesCarousel,
    required this.builder,
  });
}
