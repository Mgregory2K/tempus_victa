import 'package:flutter/material.dart';
import 'package:tempus_victa/services/consent/consent.dart';

class ConsentScreen extends StatefulWidget {
  final ConsentManager manager;
  const ConsentScreen({Key? key, required this.manager}) : super(key: key);

  @override
  _ConsentScreenState createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  @override
  Widget build(BuildContext context) {
    final consents = widget.manager.listConsents();
    return Scaffold(
      appBar: AppBar(title: Text('Consent Manager')),
      body: ListView.builder(
        itemCount: consents.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return ListTile(
              title: Text('Overview'),
              subtitle: Text('Manage AI, Sync, and Telemetry consent'),
            );
          }
          final c = consents[index - 1];
          return SwitchListTile(
            title: Text(c.scope),
            subtitle: Text('Granted at ${c.grantedAt} via ${c.via}'),
            value: c.granted,
            onChanged: (v) {
              setState(() {
                if (v) {
                  widget.manager.grant(scope: c.scope, via: 'ui:toggle');
                } else {
                  widget.manager.revoke(c.scope, via: 'ui:toggle');
                }
              });
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add sample consent for demonstration
          setState(() {
            widget.manager.grant(scope: 'ai:redacted', via: 'ui:add');
          });
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
