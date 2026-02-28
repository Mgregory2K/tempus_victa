import 'package:flutter/material.dart';

/// Minimal "Route This" trainer sheet.
/// This is intentionally tiny: it exists ONLY during the routing training window.
/// Do not expand this into a new surface; it is a gated teaching affordance.
class RouteThisSheet extends StatelessWidget {
  final String title;
  final List<_RouteChoice> choices;

  const RouteThisSheet({
    super.key,
    required this.title,
    required this.choices,
  });

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required List<RouteChoice> choices,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: false,
      builder: (_) => RouteThisSheet(
        title: title,
        choices: choices.map((c) => _RouteChoice(label: c.label, value: c.value, icon: c.icon)).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...choices.map(
              (c) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(c.icon),
                title: Text(c.label),
                onTap: () => Navigator.pop(context, c.value),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Skip'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RouteChoice {
  final String label;
  final String value;
  final IconData icon;
  const RouteChoice({required this.label, required this.value, required this.icon});
}

class _RouteChoice {
  final String label;
  final String value;
  final IconData icon;
  const _RouteChoice({required this.label, required this.value, required this.icon});
}
