enum InputType {
  voice,
  signalPromote,
  signalToCorkboard,
  signalToRecycle,
  search,
  deviceNotifications,
  deviceShares,
  corkToTask,
  corkRecycle,
  manualTaskCreate,
  attachTaskToProject,
  detachTaskFromProject,
  restoreSignal,
  saveSignalsList,
}

class SignalItemPayload {
  final String id;
  final String source;
  final String title;
  final String? body;
  final int createdAtMs;
  final int lastSeenAtMs;
  final String fingerprint;
  final int count;

  const SignalItemPayload({
    required this.id,
    required this.source,
    required this.title,
    required this.fingerprint,
    required this.createdAtMs,
    required this.lastSeenAtMs,
    this.body,
    this.count = 1,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'source': source,
        'title': title,
        'body': body,
        'createdAtMs': createdAtMs,
        'lastSeenAtMs': lastSeenAtMs,
        'fingerprint': fingerprint,
        'count': count,
      };
}

class InputEvent {
  final InputType type;
  final String? transcript;
  final String? signalId;
  final String? taskId;
  final String? projectId;
  final String? query;
  final String? corkId;
  final String? corkText;
  final String? title;
  final SignalItemPayload? signal;
  final List<Map<String, dynamic>>? items;
  final Map<String, dynamic> metadata;

  InputEvent._({
    required this.type,
    this.transcript,
    this.signalId,
    this.taskId,
    this.projectId,
    this.query,
    this.corkId,
    this.corkText,
    this.title,
    this.signal,
    this.items,
    this.metadata = const {},
  });

  factory InputEvent.voice({
    required String transcript,
    Map<String, dynamic> metadata = const {},
  }) {
    return InputEvent._(
      type: InputType.voice,
      transcript: transcript,
      metadata: metadata,
    );
  }

  factory InputEvent.signalPromote({
    required String signalId,
    Map<String, dynamic> metadata = const {},
  }) {
    return InputEvent._(
      type: InputType.signalPromote,
      signalId: signalId,
      metadata: metadata,
    );
  }

  factory InputEvent.search({
    required String query,
    Map<String, dynamic> metadata = const {},
  }) {
    return InputEvent._(
      type: InputType.search,
      query: query,
      metadata: metadata,
    );
  }

  factory InputEvent.deviceNotifications({
    required List<Map<String, dynamic>> items,
    Map<String, dynamic> metadata = const {},
  }) {
    return InputEvent._(
      type: InputType.deviceNotifications,
      items: items,
      metadata: metadata,
    );
  }

  factory InputEvent.deviceShares({
    required List<Map<String, dynamic>> items,
    Map<String, dynamic> metadata = const {},
  }) {
    return InputEvent._(
      type: InputType.deviceShares,
      items: items,
      metadata: metadata,
    );
  }


  factory InputEvent.corkToTask({
    required String corkId,
    required String text,
    Map<String, dynamic> metadata = const {},
  }) {
    return InputEvent._(
      type: InputType.corkToTask,
      corkId: corkId,
      corkText: text,
      metadata: metadata,
    );
  }

  factory InputEvent.corkRecycle({
    required String corkId,
    required String text,
    Map<String, dynamic> metadata = const {},
  }) {
    return InputEvent._(
      type: InputType.corkRecycle,
      corkId: corkId,
      corkText: text,
      metadata: metadata,
    );
  }


  factory InputEvent.manualTaskCreate({
    required String title,
    Map<String, dynamic> metadata = const {},
  }) {
    return InputEvent._(
      type: InputType.manualTaskCreate,
      title: title,
      metadata: metadata,
    );
  }

  factory InputEvent.restoreSignal({
    required SignalItemPayload signal,
    Map<String, dynamic> metadata = const {},
  }) {
    return InputEvent._(
      type: InputType.restoreSignal,
      signal: signal,
      metadata: metadata,
    );
  }

  factory InputEvent.saveSignalsList({
    required List<Map<String, dynamic>> items,
    Map<String, dynamic> metadata = const {},
  }) {
    return InputEvent._(
      type: InputType.saveSignalsList,
      items: items,
      metadata: metadata,
    );
  }


  factory InputEvent.signalToCorkboard({
    required String signalId,
    Map<String, dynamic> metadata = const {},
  }) {
    return InputEvent._(
      type: InputType.signalToCorkboard,
      signalId: signalId,
      metadata: metadata,
    );
  }

  factory InputEvent.signalToRecycle({
    required String signalId,
    Map<String, dynamic> metadata = const {},
  }) {
    return InputEvent._(
      type: InputType.signalToRecycle,
      signalId: signalId,
      metadata: metadata,
    );
  }


  factory InputEvent.attachTaskToProject({
    required String taskId,
    required String projectId,
    Map<String, dynamic> metadata = const {},
  }) {
    return InputEvent._(
      type: InputType.attachTaskToProject,
      taskId: taskId,
      projectId: projectId,
      metadata: metadata,
    );
  }

  factory InputEvent.detachTaskFromProject({
    required String taskId,
    Map<String, dynamic> metadata = const {},
  }) {
    return InputEvent._(
      type: InputType.detachTaskFromProject,
      taskId: taskId,
      metadata: metadata,
    );
  }

}
