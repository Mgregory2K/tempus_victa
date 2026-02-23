import 'package:flutter/material.dart';

import 'theme/tempus_ui.dart';
import 'theme/tempus_widgets.dart';

class RoomFrame extends StatelessWidget {
  final String title;
  final Widget child;

  /// Optional floating widget; kept for backward compatibility with Bridge.
  final Widget? floating;

  /// Optional FAB slot used by Tasks/Projects.
  final Widget? fab;

  /// Optional trailing widget in header (e.g., settings icon).
  final Widget? headerTrailing;

  const RoomFrame({
    super.key,
    required this.title,
    required this.child,
    this.floating,
    this.fab,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: TempusBackground(
            child: Column(
              children: [
                TempusAppHeader(roomTitle: title, trailing: headerTrailing),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: floating ?? fab,
    );
  }
}
