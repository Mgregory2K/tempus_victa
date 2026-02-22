class Evergreen {
  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime modifiedAt;

  Evergreen({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
  });
}

class EvergreenItem {
  final int id;
  final int evergreenId;
  final String content;
  final bool isChecked;
  final DateTime createdAt;
  final DateTime modifiedAt;

  EvergreenItem({
    required this.id,
    required this.evergreenId,
    required this.content,
    required this.isChecked,
    required this.createdAt,
    required this.modifiedAt,
  });
}
