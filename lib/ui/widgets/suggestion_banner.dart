import 'package:flutter/material.dart';

import '../../core/suggestions/suggestion.dart';

class SuggestionBanner extends StatelessWidget {
  final Suggestion suggestion;
  final VoidCallback onDismiss;
  final VoidCallback onAction;

  const SuggestionBanner({
    super.key,
    required this.suggestion,
    required this.onDismiss,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.lightbulb_outline_rounded),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(suggestion.body),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: onAction,
                        child: const Text('Do it'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: onDismiss,
                        child: const Text('Dismiss'),
                      ),
                      const Spacer(),
                      Opacity(
                        opacity: 0.7,
                        child: Text('${(suggestion.confidence * 100).round()}%'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
