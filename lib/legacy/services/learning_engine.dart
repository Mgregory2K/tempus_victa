import 'package:mobile/data/db/app_db.dart';

class LearningEngine {
  final AppDatabase _db;

  LearningEngine(this._db);

  Future<void> logSignalTriage({
    required String sourceIdentifier,
    required String signalContent,
    required String outcome,
  }) {
    return _db.into(_db.learningEvents).insert(LearningEventsCompanion.insert(
          eventTime: DateTime.now(),
          eventType: 'signal_triage',
          sourceIdentifier: sourceIdentifier,
          signalContent: signalContent,
          outcome: outcome,
        ));
  }
}
