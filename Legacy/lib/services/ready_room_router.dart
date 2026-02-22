// Lightweight router stub so Ready Room compiles and stays functional.
// Local-first: later wire lexicon + trust + cache + AI here.
class ReadyRoomRouter {
  static Future<String> route({
    required String input,
    required bool aiEnabled,
  }) async {
    final q = input.trim();
    if (q.isEmpty) return '';

    final lower = q.toLowerCase();
    final isQuestion =
        q.endsWith('?') || lower.startsWith('how ') || lower.startsWith('what ') || lower.startsWith('why ');

    if (isQuestion) {
      return aiEnabled
          ? 'AI is ON (hook local→cache→web→AI pipeline here). Query: "$q"'
          : 'AI is OFF. Local-first search hook goes here. Query: "$q"';
    }

    return 'Captured: "$q" (wire to Signal→Action/Project routing here).';
  }
}
