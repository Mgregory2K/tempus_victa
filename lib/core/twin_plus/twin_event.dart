import 'dart:convert';

enum TwinEventType {
  appStarted,
  appResumed,
  appPaused,
  roomOpened,
  roomClosed,

  textEdited,
  textSubmitted,
  styleCheckRequested,
  autocorrectOverride,

  routeChosen,
  sourceUsed,
  feedbackGiven,
  outputShaped,
}

enum TwinActor { user, system }

enum TwinPrivacy { normal, sensitiveRedacted, hashOnly }

class TwinEvent {
  final String id;
  final DateTime tsUtc;
  final String surface;
  final TwinEventType type;
  final TwinActor actor;
  final Map<String, dynamic> payload;
  final double confidence;
  final TwinPrivacy privacy;

  const TwinEvent({
    required this.id,
    required this.tsUtc,
    required this.surface,
    required this.type,
    required this.actor,
    required this.payload,
    this.confidence = 1.0,
    this.privacy = TwinPrivacy.normal,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'tsUtc': tsUtc.toIso8601String(),
        'surface': surface,
        'type': type.name,
        'actor': actor.name,
        'payload': payload,
        'confidence': confidence,
        'privacy': privacy.name,
      };

  static TwinEvent fromJson(Map<String, dynamic> j) => TwinEvent(
        id: (j['id'] ?? '') as String,
        tsUtc: DateTime.tryParse((j['tsUtc'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        surface: (j['surface'] ?? '') as String,
        type: TwinEventType.values.firstWhere(
          (e) => e.name == (j['type'] ?? '').toString(),
          orElse: () => TwinEventType.appStarted,
        ),
        actor: TwinActor.values.firstWhere(
          (e) => e.name == (j['actor'] ?? '').toString(),
          orElse: () => TwinActor.system,
        ),
        payload: (j['payload'] is Map<String, dynamic>) ? (j['payload'] as Map<String, dynamic>) : <String, dynamic>{},
        confidence: (j['confidence'] is num) ? (j['confidence'] as num).toDouble() : 1.0,
        privacy: TwinPrivacy.values.firstWhere(
          (e) => e.name == (j['privacy'] ?? '').toString(),
          orElse: () => TwinPrivacy.normal,
        ),
      );

  static TwinEvent appStarted() => TwinEvent(
        id: _id(),
        tsUtc: DateTime.now().toUtc(),
        surface: 'app',
        type: TwinEventType.appStarted,
        actor: TwinActor.system,
        payload: const {},
      );

  static TwinEvent roomOpened({required String roomId, String? roomName}) => TwinEvent(
        id: _id(),
        tsUtc: DateTime.now().toUtc(),
        surface: 'nav',
        type: TwinEventType.roomOpened,
        actor: TwinActor.system,
        payload: {'roomId': roomId, if (roomName != null) 'roomName': roomName},
      );

  static TwinEvent roomClosed({required String roomId}) => TwinEvent(
        id: _id(),
        tsUtc: DateTime.now().toUtc(),
        surface: 'nav',
        type: TwinEventType.roomClosed,
        actor: TwinActor.system,
        payload: {'roomId': roomId},
      );

  static TwinEvent textEdited({
    required String surface,
    required String fieldId,
    required int chars,
    required int words,
    required bool hasCaps,
    required bool hasProfanity,
    required double punctuationDensity,
  }) =>
      TwinEvent(
        id: _id(),
        tsUtc: DateTime.now().toUtc(),
        surface: surface,
        type: TwinEventType.textEdited,
        actor: TwinActor.user,
        payload: {
          'fieldId': fieldId,
          'chars': chars,
          'words': words,
          'hasCaps': hasCaps,
          'hasProfanity': hasProfanity,
          'punctuationDensity': punctuationDensity,
        },
        confidence: 0.95,
        privacy: TwinPrivacy.hashOnly,
      );

  static TwinEvent textSubmitted({
    required String surface,
    required String fieldId,
    required String text,
    required int chars,
    required int words,
    required bool hasCaps,
    required bool hasProfanity,
    required double punctuationDensity,
  }) =>
      TwinEvent(
        id: _id(),
        tsUtc: DateTime.now().toUtc(),
        surface: surface,
        type: TwinEventType.textSubmitted,
        actor: TwinActor.user,
        payload: {
          'fieldId': fieldId,
          'text': text,
          'chars': chars,
          'words': words,
          'hasCaps': hasCaps,
          'hasProfanity': hasProfanity,
          'punctuationDensity': punctuationDensity,
        },
        confidence: 1.0,
        privacy: TwinPrivacy.normal,
      );

  static TwinEvent feedbackGiven({
    required String surface,
    required String feedback,
    String? responseId,
    String? decisionId,
  }) =>
      TwinEvent(
        id: _id(),
        tsUtc: DateTime.now().toUtc(),
        surface: surface,
        type: TwinEventType.feedbackGiven,
        actor: TwinActor.user,
        payload: {
          'feedback': feedback,
          if (responseId != null) 'responseId': responseId,
          if (decisionId != null) 'decisionId': decisionId,
        },
      );

  static String _id() => DateTime.now().microsecondsSinceEpoch.toString();
}

String jsonLine(Map<String, dynamic> m) => jsonEncode(m);
