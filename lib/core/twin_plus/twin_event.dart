import 'dart:convert';

enum TwinEventType {appStarted,
  appResumed,
  appPaused,
  roomOpened,
  roomClosed,

  textEdited,
  textSubmitted,
  voiceCaptured,
  styleCheckRequested,
  autocorrectOverride,

  routeChosen,
  sourceUsed,
  feedbackGiven,
  outputShaped,
  actionPerformed,
  shareIngested,
  suggestionDismissed,
  suggestionGenerated,
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


  static TwinEvent voiceCaptured({
    required String surface,
    required String fieldId,
    required int durationMs,
    required String preview6,
    int? chars,
    int? words,
  }) =>
      TwinEvent(
        id: _id(),
        tsUtc: DateTime.now().toUtc(),
        surface: surface,
        type: TwinEventType.voiceCaptured,
        actor: TwinActor.user,
        payload: {
          'fieldId': fieldId,
          'durationMs': durationMs,
          'preview6': preview6,
          if (chars != null) 'chars': chars,
          if (words != null) 'words': words,
        },
        confidence: 1.0,
        privacy: TwinPrivacy.normal,
      );


  static TwinEvent shareIngested({
    required String surface,
    required String kind,
    String? text,
    String? subject,
    String? uri,
    String? mimeType,
    int? bytes,
  }) =>
      TwinEvent(
        id: _id(),
        tsUtc: DateTime.now().toUtc(),
        surface: surface,
        type: TwinEventType.shareIngested,
        actor: TwinActor.user,
        payload: {
          'kind': kind,
          if (text != null) 'text': text,
          if (subject != null) 'subject': subject,
          if (uri != null) 'uri': uri,
          if (mimeType != null) 'mimeType': mimeType,
          if (bytes != null) 'bytes': bytes,
        },
        confidence: 0.3,
      );

  static TwinEvent routeChosen({
    required String surface,
    required String decisionId,
    required String strategy,
    required double verifiabilityW,
    required double timeSensitivityW,
    required bool aiAllowed,
    required String provider,
  }) =>
      TwinEvent(
        id: _id(),
        tsUtc: DateTime.now().toUtc(),
        surface: surface,
        type: TwinEventType.routeChosen,
        actor: TwinActor.system,
        payload: {
          'decisionId': decisionId,
          'strategy': strategy,
          'verifiabilityW': verifiabilityW,
          'timeSensitivityW': timeSensitivityW,
          'aiAllowed': aiAllowed,
          'provider': provider,
        },
      );

  static TwinEvent sourceUsed({
    required String surface,
    required String decisionId,
    required String source,
    Map<String, dynamic>? meta,
  }) =>
      TwinEvent(
        id: _id(),
        tsUtc: DateTime.now().toUtc(),
        surface: surface,
        type: TwinEventType.sourceUsed,
        actor: TwinActor.system,
        payload: {
          'decisionId': decisionId,
          'source': source,
          if (meta != null) 'meta': meta,
        },
      );

  static TwinEvent feedbackGiven({
    required String surface,
    required String feedback,
    String? responseId,
    String? decisionId,
    String? details,
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
          if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
        },
      );

  static TwinEvent actionPerformed({
    required String surface,
    required String action,
    TwinActor actor = TwinActor.user,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? meta,
    double confidence = 1.0,
    TwinPrivacy privacy = TwinPrivacy.normal,
  }) {
    return TwinEvent(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      tsUtc: DateTime.now().toUtc(),
      actor: actor,
      type: TwinEventType.actionPerformed,
      surface: surface,
      confidence: confidence,
      privacy: privacy,
      payload: {
        'action': action,
        if (entityType != null) 'entityType': entityType,
        if (entityId != null) 'entityId': entityId,
        if (meta != null) 'meta': meta,
      },
    );
  }

  static TwinEvent suggestionGenerated({
    required String surface,
    required String suggestionKind,
    required double confidence,
    Map<String, dynamic>? payload,
    TwinActor actor = TwinActor.system,
    TwinPrivacy privacy = TwinPrivacy.normal,
  }) {
    return TwinEvent(
      id: _id(),
      tsUtc: DateTime.now().toUtc(),
      surface: surface,
      type: TwinEventType.suggestionGenerated,
      actor: actor,
      confidence: confidence,
      privacy: privacy,
      payload: {
        'kind': suggestionKind,
        if (payload != null) ...payload,
      },
    );
  }

  static TwinEvent suggestionDismissed({
    required String surface,
    required String suggestionKind,
    Map<String, dynamic>? payload,
    TwinActor actor = TwinActor.user,
    TwinPrivacy privacy = TwinPrivacy.normal,
  }) {
    return TwinEvent(
      id: _id(),
      tsUtc: DateTime.now().toUtc(),
      surface: surface,
      type: TwinEventType.suggestionDismissed,
      actor: actor,
      confidence: 0.5,
      privacy: privacy,
      payload: {
        'kind': suggestionKind,
        if (payload != null) ...payload,
      },
    );
  }

  static String _id() => DateTime.now().microsecondsSinceEpoch.toString();
}

String jsonLine(Map<String, dynamic> m) => jsonEncode(m);
