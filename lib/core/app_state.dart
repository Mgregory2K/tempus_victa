import 'package:flutter/foundation.dart';

import 'app_mode.dart';

class AppState extends ChangeNotifier {
  AppMode mode = AppMode.normal;

  // Nav
  String selectedModuleId;
  List<String> moduleOrderIds;

  // Simple signal to refresh tasks UI when new tasks are created.
  int tasksVersion = 0;

  AppState({
    required this.selectedModuleId,
    required this.moduleOrderIds,
  });

  void setSelectedModule(String id) {
    if (selectedModuleId == id) return;
    selectedModuleId = id;
    notifyListeners();
  }

  void bumpTasksVersion() {
    tasksVersion++;
    notifyListeners();
  }
}
