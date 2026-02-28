import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'quote_board_store.dart';

/// ZIP 6 — User-writable BoQ file.
///
/// - On first run, copies the bundled seed asset (lib/assets/BoQ.md)
///   into app documents storage as BoQ_user.md
/// - Quote Board uses this as its seed and also keeps it updated
class BoQFileStore {
  static const String _assetPath = 'lib/assets/BoQ.md';
  static const String _userFileName = 'BoQ_user.md';

  static Future<File> _userFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_userFileName');
  }

  static Future<void> ensureSeeded() async {
    final f = await _userFile();
    if (await f.exists()) return;

    final seeded = await rootBundle.loadString(_assetPath);
    await f.writeAsString(seeded);
  }

  static Future<String> loadMarkdown() async {
    await ensureSeeded();
    final f = await _userFile();
    return f.readAsString();
  }

  static Future<void> saveMarkdown(String markdown) async {
    final f = await _userFile();
    await f.writeAsString(markdown);
  }

  /// Parse BoQ markdown into QuoteEntry objects.
  /// Supported patterns:
  /// - ### “Quote text”
  ///   **Use when:**
  ///   some text...
  /// - ### "Quote text"
  ///   — Author
  ///   Source: Something
  static List<QuoteEntry> parseEntries(String markdown) {
    final lines = markdown.split('\n');
    final out = <QuoteEntry>[];

    String? currentQuote;
    String? currentAuthor;
    String? currentSource;
    final useWhenBuf = StringBuffer();

    void flush() {
      final q = (currentQuote ?? '').trim();
      if (q.isEmpty) {
        currentQuote = null;
        currentAuthor = null;
        currentSource = null;
        useWhenBuf.clear();
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final useWhen = useWhenBuf.toString().trim();
      final src = (currentSource?.trim().isEmpty ?? true)
          ? (useWhen.isEmpty ? 'BoQ_user.md' : useWhen)
          : currentSource!.trim();

      out.add(QuoteEntry(
        id: '${now}_${out.length}',
        quote: q,
        author: (currentAuthor ?? '').trim(),
        source: src,
        createdAtEpochMs: now,
      ));

      currentQuote = null;
      currentAuthor = null;
      currentSource = null;
      useWhenBuf.clear();
    }

    bool inUseWhen = false;

    for (final raw in lines) {
      final line = raw.trimRight();

      // New quote header
      if (line.trimLeft().startsWith('### ')) {
        flush();
        inUseWhen = false;

        var q = line.trimLeft().substring(4).trim();
        // Strip wrapping quotes
        q = q.replaceAll('“', '"').replaceAll('”', '"');
        if (q.startsWith('"') && q.endsWith('"') && q.length >= 2) {
          q = q.substring(1, q.length - 1).trim();
        }
        currentQuote = q;
        continue;
      }

      if (currentQuote == null) continue;

      final l = line.trim();

      // Use-when marker
      if (l.toLowerCase().startsWith('**use when')) {
        inUseWhen = true;
        continue;
      }

      // Author line like: — Author
      if (l.startsWith('—') || l.startsWith('--')) {
        currentAuthor = l.replaceFirst(RegExp(r'^(—|--)+\s*'), '').trim();
        continue;
      }

      // Source line
      if (l.toLowerCase().startsWith('source:')) {
        currentSource = l.substring('source:'.length).trim();
        continue;
      }

      // Collect use-when block until blank line or next header
      if (inUseWhen) {
        if (l.isEmpty) {
          inUseWhen = false;
        } else {
          if (useWhenBuf.isNotEmpty) useWhenBuf.writeln();
          useWhenBuf.write(l);
        }
      }
    }

    flush();
    return out;
  }

  /// Write a simple, stable markdown representation for all quote entries.
  /// This keeps the BoQ living per user even if the UI store is JSON.
  static Future<void> writeFromEntries(List<QuoteEntry> entries) async {
    final buf = StringBuffer();
    buf.writeln('# Book of Quotes (User)');
    buf.writeln('This file is user-writable and is kept in sync with Quote Board.');
    buf.writeln('');
    buf.writeln('---');
    buf.writeln('');
    buf.writeln('## Quotes');
    buf.writeln('');

    for (final e in entries) {
      final q = e.quote.trim();
      if (q.isEmpty) continue;

      buf.writeln('### "${q.replaceAll('"', '"')}"');
      if (e.author.trim().isNotEmpty) {
        buf.writeln('— ${e.author.trim()}');
      }
      if ((e.source ?? '').trim().isNotEmpty) {
        buf.writeln('Source: ${(e.source ?? '').trim()}');
      }
      buf.writeln('');
    }

    await saveMarkdown(buf.toString());
  }
}
