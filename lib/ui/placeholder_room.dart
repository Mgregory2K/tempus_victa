import 'package:flutter/material.dart';
import 'room_frame.dart';

class PlaceholderRoom extends StatelessWidget {
  final String roomName;

  const PlaceholderRoom({super.key, required this.roomName});

  @override
  Widget build(BuildContext context) {
    return RoomFrame(
      title: roomName,
      child: Center(
        child: Text(
          roomName,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
