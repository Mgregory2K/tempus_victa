import 'package:flutter/material.dart';

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
