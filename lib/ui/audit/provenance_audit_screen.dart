import 'package:flutter/material.dart';

class ProvenanceAuditScreen extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  const ProvenanceAuditScreen({Key? key, required this.entries})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Provenance Audit')),
      body: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, __) => Divider(height: 1),
        itemBuilder: (context, index) {
          final e = entries[index];
          return ListTile(
            title: Text(e['action'] ?? 'action'),
            subtitle:
                Text('actor: ${e['actor'] ?? 'n/a'}\n${e['timestamp'] ?? ''}'),
            isThreeLine: true,
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text('Provenance ${e['prov_id'] ?? ''}'),
                  content: SingleChildScrollView(child: Text(e.toString())),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
