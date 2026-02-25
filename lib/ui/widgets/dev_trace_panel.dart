import 'package:flutter/material.dart';

class DevTracePanel extends StatelessWidget {
  final List<String> lines;
  const DevTracePanel({super.key, required this.lines});

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Card(
        child: ExpansionTile(
          title: const Text('Dev Mode — Debug Trace'),
          initiallyExpanded: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lines.map((l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(l, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
