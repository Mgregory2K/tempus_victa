import 'app_state.dart';
import '../models/task.dart';

class LifecycleService {
  final AppState state;

  LifecycleService(this.state);

  Future<void> promoteSignalToTask(String content) async {
    await state.addTask(content);
  }
}
