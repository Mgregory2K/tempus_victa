class SuggestionResult {
  final String kind; // list_add
  final String listName;
  final List<String> items;
  final double confidence;

  const SuggestionResult({
    required this.kind,
    required this.listName,
    required this.items,
    required this.confidence,
  });
}
