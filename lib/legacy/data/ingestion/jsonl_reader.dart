import 'dart:convert';
import 'dart:io';

class JsonlReader {
  Future<List<Map<String, dynamic>>> readAll(File file) async {
    if (!await file.exists()) return [];
    final lines = await file.readAsLines();
    return lines
        .where((l) => l.trim().isNotEmpty)
        .map((l) => jsonDecode(l) as Map<String, dynamic>)
        .toList();
  }
}
