import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/quote_board_store.dart';

class QuoteBoardRoom extends StatefulWidget {
  final String? roomName;
  const QuoteBoardRoom({super.key, this.roomName});

  @override
  State<QuoteBoardRoom> createState() => _QuoteBoardRoomState();
}

class _QuoteBoardRoomState extends State<QuoteBoardRoom> {
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  List<QuoteEntry> _quotes = <QuoteEntry>[];

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loaded = await QuoteBoardStore.load();

    // Seed on first run.
    if (loaded.isEmpty) {
      final seeded = await _trySeedFromAsset();
      if (seeded.isNotEmpty) {
        await QuoteBoardStore.save(seeded);
        if (!mounted) return;
        setState(() {
          _quotes = seeded;
          _loading = false;
        });
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _quotes = loaded;
      _loading = false;
    });
  }

  Future<List<QuoteEntry>> _trySeedFromAsset() async {
    try {
      final raw = await rootBundle.loadString('assets/BoQ.md');
      return _parseBoqMarkdown(raw);
    } catch (_) {
      return <QuoteEntry>[];
    }
  }

  List<QuoteEntry> _parseBoqMarkdown(String raw) {
    // Expected format per entry:
    // <i>"..."</i>
    // -Socrates
    final lines = const LineSplitter().convert(raw);
    final entries = <QuoteEntry>[];

    String? pendingQuote;
    String? pendingSource;

    void flush(String authorLine) {
      final q = (pendingQuote ?? '').trim();
      if (q.isEmpty) {
        pendingQuote = null;
        pendingSource = null;
        return;
      }
      final author = authorLine.trim().replaceFirst(RegExp(r'^-+\s*'), '').trim();
      if (author.isEmpty) {
        pendingQuote = null;
        pendingSource = null;
        return;
      }
      entries.add(
        QuoteEntry(
          id: DateTime.now().microsecondsSinceEpoch.toString() + '_${entries.length}',
          quote: q,
          author: author,
          source: pendingSource?.trim().isEmpty == true ? null : pendingSource?.trim(),
          createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      pendingQuote = null;
      pendingSource = null;
    }

    for (final ln in lines) {
      final line = ln.trim();
      if (line.isEmpty) continue;

      // Author line.
      if (line.startsWith('-') && !line.startsWith('---')) {
        flush(line);
        continue;
      }

      // Quote line.
      if (pendingQuote == null) {
        pendingQuote = _stripItalicsTags(line);
        // Remove outer quotes if present.
        pendingQuote = pendingQuote!.replaceAll(RegExp(r'^"|"$'), '').trim();
        continue;
      }

      // Optional: treat extra non-author lines as "source" or continuation.
      // If it looks like a URL or short attribution, store it; otherwise append.
      if (pendingSource == null && (line.startsWith('http://') || line.startsWith('https://') || line.length <= 80)) {
        pendingSource = _stripItalicsTags(line);
      } else {
        pendingQuote = '${pendingQuote!}\n${_stripItalicsTags(line)}'.trim();
      }
    }

    return entries;
  }

  String _stripItalicsTags(String s) {
    return s.replaceAll('<i>', '').replaceAll('</i>', '').trim();
  }

  List<QuoteEntry> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _quotes;
    return _quotes.where((e) {
      return e.quote.toLowerCase().contains(q) || e.author.toLowerCase().contains(q) || (e.source ?? '').toLowerCase().contains(q);
    }).toList(growable: false);
  }

  Future<void> _addQuote() async {
    final created = await showDialog<QuoteEntry>(
      context: context,
      builder: (_) => const _AddQuoteDialog(),
    );
    if (created == null) return;

    final next = [..._quotes, created];
    setState(() => _quotes = next);
    await QuoteBoardStore.save(next);
  }

  Future<void> _exportJson() async {
    final jsonStr = jsonEncode(_quotes.map((e) => e.toJson()).toList(growable: false));
    await Clipboard.setData(ClipboardData(text: jsonStr));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Quote Board exported to clipboard (JSON).')),
    );
  }

  Future<void> _importJson() async {
    final data = await Clipboard.getData('text/plain');
    final raw = (data?.text ?? '').trim();
    if (raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final imported = decoded
          .whereType<Map>()
          .map((m) => QuoteEntry.fromJson(m.cast<String, dynamic>()))
          .where((e) => e.quote.trim().isNotEmpty && e.author.trim().isNotEmpty)
          .toList(growable: false);
      if (imported.isEmpty) return;

      // Additive import: keep existing, append new ids; de-dupe by quote+author.
      final existingKey = _quotes.map((e) => '${e.author}::${e.quote}'.toLowerCase()).toSet();
      final toAdd = <QuoteEntry>[];
      for (final e in imported) {
        final key = '${e.author}::${e.quote}'.toLowerCase();
        if (existingKey.contains(key)) continue;
        existingKey.add(key);
        toAdd.add(
          e.id.trim().isEmpty
              ? e.copyWith(id: DateTime.now().microsecondsSinceEpoch.toString())
              : e,
        );
      }
      if (toAdd.isEmpty) return;

      final next = [..._quotes, ...toAdd];
      setState(() => _quotes = next);
      await QuoteBoardStore.save(next);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${toAdd.length} quotes.')),
      );
    } catch (_) {
      // Ignore.
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Quote Board?'),
        content: const Text('This deletes the local Quote Board on this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    await QuoteBoardStore.clear();
    if (!mounted) return;
    setState(() => _quotes = <QuoteEntry>[]);
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Text('Quote Board', style: TextStyle(fontWeight: FontWeight.w900)),
                const Spacer(),
                IconButton(
                  tooltip: 'Import JSON from clipboard',
                  onPressed: _importJson,
                  icon: const Icon(Icons.download_rounded),
                ),
                IconButton(
                  tooltip: 'Export JSON to clipboard',
                  onPressed: _exportJson,
                  icon: const Icon(Icons.upload_rounded),
                ),
                IconButton(
                  tooltip: 'Clear',
                  onPressed: _clear,
                  icon: const Icon(Icons.delete_outline),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search quotes or authors…',
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? const Center(child: Text('No quotes yet. Add one.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: items.length,
                        itemBuilder: (_, i) => _QuoteCard(entry: items[i]),
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _addQuote,
                  icon: const Icon(Icons.add),
                  label: const Text('Add quote'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final QuoteEntry entry;
  const _QuoteCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('“${entry.quote.trim()}”', style: t.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic)),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('- ${entry.author}', style: const TextStyle(fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  tooltip: 'Copy',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: '"${entry.quote}"\n-${entry.author}'));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied.')));
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
            if ((entry.source ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(entry.source!, style: TextStyle(color: t.colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddQuoteDialog extends StatefulWidget {
  const _AddQuoteDialog();

  @override
  State<_AddQuoteDialog> createState() => _AddQuoteDialogState();
}

class _AddQuoteDialogState extends State<_AddQuoteDialog> {
  final _quoteCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _sourceCtrl = TextEditingController();

  @override
  void dispose() {
    _quoteCtrl.dispose();
    _authorCtrl.dispose();
    _sourceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add quote'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _quoteCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Quote'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _authorCtrl,
              decoration: const InputDecoration(labelText: 'Author'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sourceCtrl,
              decoration: const InputDecoration(labelText: 'Source (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final q = _quoteCtrl.text.trim();
            final a = _authorCtrl.text.trim();
            if (q.isEmpty || a.isEmpty) return;
            Navigator.of(context).pop(
              QuoteEntry(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                quote: q,
                author: a,
                source: _sourceCtrl.text.trim().isEmpty ? null : _sourceCtrl.text.trim(),
                createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
