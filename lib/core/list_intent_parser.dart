class ListIntent {
  final String action; // create|add|remove|clear|show
  final String listName;
  final List<String> items;

  const ListIntent({required this.action, required this.listName, this.items = const []});
}

class ListIntentParser {
  static ListIntent? parse(String transcript) {
    final raw = transcript.trim();
    if (raw.isEmpty) return null;

    final lower = raw.toLowerCase();

    // Pattern: "<listname>: item1, item2" (e.g., "grocery: milk, eggs")
    // Treat as add-items intent (create list if missing is handled by executor/store).
    final colonMatch = RegExp(r'^([a-z][a-z0-9 _-]{1,40})\s*:\s*(.+)$', caseSensitive: false)
        .firstMatch(raw);
    if (colonMatch != null) {
      final name = (colonMatch.group(1) ?? '').trim();
      final rest = (colonMatch.group(2) ?? '').trim();
      if (name.isNotEmpty && rest.isNotEmpty) {
        final items = rest
            .split(RegExp(r'\s*,\s*'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(growable: false);
        if (items.isNotEmpty) {
          return ListIntent(action: 'add', listName: _titleCase(name), items: items);
        }
      }
    }



    // clear <list>
    final clear = RegExp(r'^clear\s+(.+?)(?:\s+list)?\s*$').firstMatch(lower);
    if (clear != null) {
      final name = _titleize(clear.group(1) ?? '');
      if (name.isNotEmpty) return ListIntent(action: 'clear', listName: name);
    }

    // show <list>
    final show = RegExp(r'^(show|open)\s+(.+?)(?:\s+list)?\s*$').firstMatch(lower);
    if (show != null) {
      final name = _titleize(show.group(2) ?? '');
      if (name.isNotEmpty) return ListIntent(action: 'show', listName: name);
    }

    // create <list> list [add <items>]
    final create = RegExp(r'^create\s+(.+?)(?:\s+list)?(?:\s+add\s+(.+))?\s*$').firstMatch(lower);
    if (create != null) {
      final name = _titleize(create.group(1) ?? '');
      final items = _splitItems(create.group(2) ?? '');
      if (name.isNotEmpty) return ListIntent(action: 'create', listName: name, items: items);
    }

    // add <items> to <list>
    final add = RegExp(r'^add\s+(.+?)\s+(?:to|into)\s+(.+?)(?:\s+list)?\s*$').firstMatch(lower);
    if (add != null) {
      final items = _splitItems(add.group(1) ?? '');
      final name = _titleize(add.group(2) ?? '');
      if (name.isNotEmpty && items.isNotEmpty) return ListIntent(action: 'add', listName: name, items: items);
    }

    // remove <items> from <list>
    final rem = RegExp(r'^(remove|delete)\s+(.+?)\s+from\s+(.+?)(?:\s+list)?\s*$').firstMatch(lower);
    if (rem != null) {
      final items = _splitItems(rem.group(2) ?? '');
      final name = _titleize(rem.group(3) ?? '');
      if (name.isNotEmpty && items.isNotEmpty) return ListIntent(action: 'remove', listName: name, items: items);
    }

    // add milk, eggs grocery (no "to")
    final looseAdd = RegExp(r'^add\s+(.+?)\s+(.+?)(?:\s+list)?\s*$').firstMatch(lower);
    if (looseAdd != null) {
      final items = _splitItems(looseAdd.group(1) ?? '');
      final name = _titleize(looseAdd.group(2) ?? '');
      if (name.isNotEmpty && items.isNotEmpty) return ListIntent(action: 'add', listName: name, items: items);
    }

    return null;
  }

  static List<String> _splitItems(String s) {
    final raw = s.trim();
    if (raw.isEmpty) return const [];
    // split by comma first, else by " and "
    final parts = raw.contains(',')
        ? raw.split(',')
        : raw.split(RegExp(r'\s+and\s+'));
    return parts.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
  }

  static String _titleize(String s) {
    final raw = s.trim();
    if (raw.isEmpty) return '';
    final words = raw.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return words.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  static String _titleCase(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    final parts = t.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList(growable: false);
    return parts
        .map((p) => p.length == 1 ? p.toUpperCase() : (p[0].toUpperCase() + p.substring(1).toLowerCase()))
        .join(' ');
  }


}
