import 'package:flutter/material.dart';

import '../../core/app_settings_store.dart';

/// Shared top header for rooms.
///
/// Keeps the look consistent and provides an optional trailing widget for
/// room-specific actions.
class TempusAppHeader extends StatelessWidget {
  final String roomTitle;
  final Widget? trailing;

  const TempusAppHeader({
    super.key,
    required this.roomTitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
              onLongPress: () async {
                final next = await AppSettingsStore().toggleDevMode();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Dev Mode: ${next ? 'ON' : 'OFF'}')),
                );
              },
              child: Text(
                roomTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface,
                  fontSize: 18,
                ),
              ),
            ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
