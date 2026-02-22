import 'package:flutter/material.dart';

class RoomScreen extends StatefulWidget {
  final String roomName;

  const RoomScreen({super.key, required this.roomName});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // keeps state alive in IndexedStack

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Center(
      child: Text(
        widget.roomName,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}