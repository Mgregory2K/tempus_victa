import 'package:flutter/material.dart';

class RoomFrame extends StatelessWidget {
  final String title;
  final Widget child;

  /// Optional FAB slot used by Tasks, Projects, etc.
  final Widget? fab;

  /// Alias for FAB used by Bridge (older param name).
  /// If both [floating] and [fab] are provided, [floating] wins.
  final Widget? floating;

  const RoomFrame({
    super.key,
    required this.title,
    required this.child,
    this.fab,
    this.floating,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: false,
      ),
      body: SafeArea(child: child),
      floatingActionButton: floating ?? fab,
    );
  }
}
