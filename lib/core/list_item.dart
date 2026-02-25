class ListEntry {
  final String id;
  final DateTime createdAt;
  final String text;
  final bool checked;

  const ListEntry({
    required this.id,
    required this.createdAt,
    required this.text,
    required this.checked,
  });

  ListEntry copyWith({String? text, bool? checked}) => ListEntry(
        id: id,
        createdAt: createdAt,
        text: text ?? this.text,
        checked: checked ?? this.checked,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'text': text,
        'checked': checked,
      };

  static ListEntry fromJson(Map<String, dynamic> j) => ListEntry(
        id: (j['id'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
        text: (j['text'] ?? '').toString(),
        checked: (j['checked'] ?? false) == true,
      );
}

class ListItem {
  final String id;
  final DateTime createdAt;
  final String name;
  final List<ListEntry> entries;

  const ListItem({
    required this.id,
    required this.createdAt,
    required this.name,
    required this.entries,
  });

  ListItem copyWith({String? name, List<ListEntry>? entries}) => ListItem(
        id: id,
        createdAt: createdAt,
        name: name ?? this.name,
        entries: entries ?? this.entries,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'name': name,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  static ListItem fromJson(Map<String, dynamic> j) => ListItem(
        id: (j['id'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
        name: (j['name'] ?? 'List').toString(),
        entries: (j['entries'] is List)
            ? (j['entries'] as List)
                .whereType<Map>()
                .map((e) => ListEntry.fromJson(e.cast<String, dynamic>()))
                .toList(growable: false)
            : <ListEntry>[],
      );
}
