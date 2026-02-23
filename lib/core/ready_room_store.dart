import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ReadyRoomMessage {
  final String id;
  final String role; // 'user' | 'assistant' | 'system'
  final String text;
  final int createdAtEpochMs;

  ReadyRoomMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAtEpochMs,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'text': text,
        'createdAtEpochMs': createdAtEpochMs,
      };

  static ReadyRoomMessage fromJson(Map<String, dynamic> j) => ReadyRoomMessage(
        id: (j['id'] ?? '').toString(),
        role: (j['role'] ?? 'user').toString(),
        text: (j['text'] ?? '').toString(),
        createdAtEpochMs: j['createdAtEpochMs'] is int
            ? j['createdAtEpochMs'] as int
            : int.tryParse('${j['createdAtEpochMs']}') ?? DateTime.now().millisecondsSinceEpoch,
      );
}

class ReadyRoomStore {
  static const String _kKey = 'tempus.ready_room.messages.v1';
  static const int _kMaxMessages = 200;

  static Future<List<ReadyRoomMessage>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return <ReadyRoomMessage>[];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <ReadyRoomMessage>[];

    return decoded
        .whereType<Map>()
        .map((m) => ReadyRoomMessage.fromJson(m.cast<String, dynamic>()))
        .where((m) => m.text.trim().isNotEmpty)
        .toList();
  }

  static Future<void> save(List<ReadyRoomMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = messages.length <= _kMaxMessages
        ? messages
        : messages.sublist(messages.length - _kMaxMessages);
    final raw = jsonEncode(trimmed.map((m) => m.toJson()).toList());
    await prefs.setString(_kKey, raw);
  }

  static Future<void> append(ReadyRoomMessage msg) async {
    final msgs = await load();
    msgs.add(msg);
    await save(msgs);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}
