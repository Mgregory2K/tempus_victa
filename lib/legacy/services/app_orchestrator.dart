import 'ai/ai_settings.dart';
import 'research/research_settings.dart';
import 'ingestion/ingestion_dispatcher.dart';

/// One place to initialize app services and apply sticky settings.
/// Keep this small and boring: no rebuilds, no hidden state.
class AppOrchestrator {
  AppOrchestrator._();

  static final AppOrchestrator I = AppOrchestrator._();

  bool _didInit = false;

  Future<void> init() async {
    if (_didInit) return;// Touch settings so meta keys exist (optional, safe).
    await ResearchSettings.getWebEnabled();
    await AiSettings.getEnabled();

    // Apply ingestion toggles.
    await IngestionDispatcher.I.applyCurrentSettings();

    _didInit = true;
  }
}
