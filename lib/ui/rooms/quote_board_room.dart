import 'package:flutter/material.dart';

import '../room_frame.dart';
import '../theme/tempus_ui.dart';

class QuoteBoardRoom extends StatelessWidget {
  final String roomName;
  const QuoteBoardRoom({super.key, required this.roomName});

  @override
  Widget build(BuildContext context) {
    return RoomFrame(
      title: roomName,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TempusCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Quote Board', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                SizedBox(height: 8),
                Text(
                  'This module is reserved for saved quotes and reflections. '
                  'Analyze lives in the Analyze room (not here).',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
