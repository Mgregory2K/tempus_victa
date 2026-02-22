import 'package:flutter/material.dart';

class RoomFrame extends StatelessWidget {
  final String title;
  final Widget child;

  /// Optional floating widget; kept for backward compatibility with Bridge.
  final Widget? floating;

  /// Optional FAB slot used by Tasks/Projects.
  final Widget? fab;

  const RoomFrame({
    super.key,
    required this.title,
    required this.child,
    this.floating,
    this.fab,
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
