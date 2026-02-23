import 'package:flutter/material.dart';

import '../room_frame.dart';
import '../theme/tempus_ui.dart';

class QuoteBoardRoom extends StatelessWidget {
  final String roomName;
  const QuoteBoardRoom({super.key, required this.roomName});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return RoomFrame(
      title: 'Quote Board',
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          TempusCard(
            elevated: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Book of Quotes', style: t.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'This board will hold your quotes and “rules of engagement.”',
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TempusCard(
            child: Text(
              'No quotes yet. (This is intentionally NOT the Analyze screen.)',
              style: t.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
