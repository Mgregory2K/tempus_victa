import 'app_state.dart';

class IngestionService {
  final AppState state;

  IngestionService(this.state);

  Future<void> ingest(String input) async {
    await state.addSignal(input, "manual");
  }
}
