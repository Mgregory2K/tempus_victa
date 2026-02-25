import 'package:flutter/material.dart';

import '../../core/unified_index_service.dart';
import '../room_frame.dart';
import '../theme/tv_textfield.dart';
import '../theme/tempus_ui.dart';

class GlobalSearchRoom extends StatefulWidget {
  final String roomName;
  const GlobalSearchRoom({super.key, required this.roomName});

  @override
  State<GlobalSearchRoom> createState() => _GlobalSearchRoomState();
}

class _GlobalSearchRoomState extends State<GlobalSearchRoom> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = const [];
  bool _loading = false;

  Future<void> _run() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() => _loading = true);
    final res = await UnifiedIndexService.search(q);
    if (!mounted) return;
    setState(() {
      _results = res;
      _loading = false;
    });
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'task':
        return 'Task';
      case 'project':
        return 'Project';
      case 'cork':
        return 'Corkboard';
      case 'signal':
        return 'Signal';
      default:
        return t;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoomFrame(
      title: widget.roomName,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TvTextField(
                    controller: _controller,
                    hintText: 'Search everything…',
                    prefixIcon: Icons.search,
                    twinSurface: 'global_search',
                    twinFieldId: 'query',
                    onSubmitted: (_) => _run(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _loading ? null : _run,
                  child: const Text('Go'),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _controller.text.trim().isEmpty ? 'Search across everything.' : 'No results.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    itemBuilder: (ctx, i) {
                      final e = _results[i];
                      final type = (e['type'] ?? '').toString();
                      final title = (e['title'] ?? '').toString();
                      final body = (e['body'] ?? '').toString();
                      return TempusCard(
                        child: ListTile(
                          title: Text(title.isEmpty ? '(untitled)' : title),
                          subtitle: Text('${_typeLabel(type)}${body.trim().isEmpty ? '' : ' • ${body.trim()}'}'),
                          onTap: () {
                            // Drilldown routing will be wired next phase.
                            // For now, keep clickable behavior without guessing routes.
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Open: ${_typeLabel(type)}')),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
