
import 'package:flutter/material.dart';

class NavigatorService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static void openEntity(String? type, String? id) {
    if (type == null || id == null) return;

    switch (type) {
      case 'task':
        navigatorKey.currentState?.pushNamed('/taskDetail', arguments: id);
        break;
      case 'project':
        navigatorKey.currentState?.pushNamed('/projectDetail', arguments: id);
        break;
      case 'list':
        navigatorKey.currentState?.pushNamed('/listDetail', arguments: id);
        break;
      case 'signal':
        navigatorKey.currentState?.pushNamed('/signalDetail', arguments: id);
        break;
      case 'cork':
        navigatorKey.currentState?.pushNamed('/corkDetail', arguments: id);
        break;
      default:
        break;
    }
  }
}
