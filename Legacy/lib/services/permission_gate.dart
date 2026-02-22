import 'package:permission_handler/permission_handler.dart';

class PermissionGate {
  Future<bool> requestNotificationAccess() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }
}
