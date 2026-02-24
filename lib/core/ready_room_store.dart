import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence for Ready Room chat feed.
/// NOTE: This is intentionally lightweight and local-first.
class ReadyRoomMessage {
  final String id;
  final String role; // 'user' | 'assistant' | 'system'
  final String text;
  final int createdAtEpochMs;

  /// Optional: decision id from Twin+ routing (if available).
  final String? decisionId;

  /// Optional per-assistant-message vote: 1=up, -1=down, null=none
  final int? vote;

  /// Optional flag when user marks the response as wrong source / stale.
  final bool wrongSource;

  ReadyRoomMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAtEpochMs,
    this.decisionId,
    this.vote,
    this.wrongSource = false,
  });

  ReadyRoomMessage copyWith({
    String? id,
    String? role,
    String? text,
    int? createdAtEpochMs,
    String? decisionId,
    int? vote,
    bool? wrongSource,
  }) {
    return ReadyRoomMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      text: text ?? this.text,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      decisionId: decisionId ?? this.decisionId,
      vote: vote ?? this.vote,
      wrongSource: wrongSource ?? this.wrongSource,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'text': text,
        'createdAtEpochMs': createdAtEpochMs,
        if (decisionId != null) 'decisionId': decisionId,
        if (vote != null) 'vote': vote,
        if (wrongSource) 'wrongSource': true,
      };

  static ReadyRoomMessage fromJson(Map<String, dynamic> j) => ReadyRoomMessage(
        id: (j['id'] ?? '').toString(),
        role: (j['role'] ?? 'user').toString(),
        text: (j['text'] ?? '').toString(),
        createdAtEpochMs: j['createdAtEpochMs'] is int
            ? j['createdAtEpochMs'] as int
            : int.tryParse('${j['createdAtEpochMs']}') ?? DateTime.now().millisecondsSinceEpoch,
        decisionId: (j['decisionId'] == null) ? null : j['decisionId'].toString(),
        vote: (j['vote'] is int) ? j['vote'] as int : int.tryParse('${j['vote']}'),
        wrongSource: j['wrongSource'] == true,
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

  /// Replace a single message (by id) and persist.
  static Future<void> upsert(ReadyRoomMessage msg) async {
    final msgs = await load();
    final idx = msgs.indexWhere((m) => m.id == msg.id);
    if (idx == -1) {
      msgs.add(msg);
    } else {
      msgs[idx] = msg;
    }
    await save(msgs);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}
