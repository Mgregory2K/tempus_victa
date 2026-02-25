import 'package:flutter/material.dart';

import '../core/twin_plus/twin_event.dart';
import '../core/twin_plus/twin_plus_scope.dart';
import 'widgets/tempus_app_header.dart';
import 'widgets/tempus_background.dart';

/// Standard room scaffold wrapper.
/// Additive wiring: emits Twin+ room open/close events so the system can learn
/// navigation patterns across the entire app (opt-in learning is enforced by prefs).
class RoomFrame extends StatefulWidget {
  final String title;
  final Widget child;
  final Widget? floating;
  final Widget? fab;
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
  State<RoomFrame> createState() => _RoomFrameState();
}

class _RoomFrameState extends State<RoomFrame> {
  bool _openedEmitted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_openedEmitted) return;
    _openedEmitted = true;

    final kernel = TwinPlusScope.maybeOf(context);
    if (kernel != null) {
      kernel.observe(
        TwinEvent.roomOpened(
          roomId: widget.title,
          roomName: widget.title,
        ),
      );
    }
  }

  @override
  void dispose() {
    final kernel = TwinPlusScope.maybeOf(context);
    if (kernel != null) {
      kernel.observe(
        TwinEvent.roomClosed(
          roomId: widget.title,
        ),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final floatingActionButton = widget.floating ?? widget.fab;

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: TempusBackground(
            child: Column(
              children: [
                TempusAppHeader(roomTitle: widget.title, trailing: widget.headerTrailing),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
