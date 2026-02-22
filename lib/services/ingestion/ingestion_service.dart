// Tempus Victa - Ingestion Service
//
// Ingestion doctrine:
// - Everything is a Signal first.
// - Sources: text, voice, share sheet, notifications (listener), and future hooks.
// - Always timestamp at capture and persist immediately.

import '../voice/voice_service.dart';
import 'share_intent_service.dart';
import 'notification_intent_service.dart';

class IngestionService {
  IngestionService._();
  static final IngestionService instance = IngestionService._();

  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    // Initialize voice engine early for low-latency.
    await VoiceService.instance.init();

    // Android share-sheet ingestion.
    await ShareIntentService.instance.start();

    // Android notification listener ingestion (requires user enabling access).
    await NotificationIntentService.instance.start();
  }
}
