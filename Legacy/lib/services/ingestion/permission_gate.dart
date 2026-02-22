import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Centralized runtime permission requesting.
/// Some capabilities (Notification Listener) still require user enabling
/// in system settings; this class only handles runtime permissions.
class PermissionGate {
  static Future<bool> requestSms() async {
    final s = await Permission.sms.request();
    return s.isGranted;
  }

  static Future<bool> requestPhone() async {
    // For call log access.
    final s = await Permission.phone.request();
    return s.isGranted;
  }

  static Future<bool> requestContacts() async {
    final s = await Permission.contacts.request();
    return s.isGranted;
  }

  static Future<bool> requestCalendar() async {
    final s = await Permission.calendar.request();
    return s.isGranted;
  }

  static Future<bool> requestNotifications() async {
    // Android 13+ runtime notifications permission.
    final s = await Permission.notification.request();
    return s.isGranted;
  }

  static Future<void> openAppSettingsPage() async {
    await openAppSettings();
  }

  static Future<Map<String, PermissionStatus>> statusSnapshot() async {
    return <String, PermissionStatus>{
      'notification': await Permission.notification.status,
      'sms': await Permission.sms.status,
      'phone': await Permission.phone.status,
      'calendar': await Permission.calendar.status,
      'contacts': await Permission.contacts.status,
    };
  }

  static Color colorFor(PermissionStatus s) {
    if (s.isGranted) return Colors.green;
    if (s.isLimited) return Colors.orange;
    if (s.isDenied) return Colors.orange;
    if (s.isPermanentlyDenied) return Colors.red;
    return Colors.grey;
  }

  static String labelFor(PermissionStatus s) {
    if (s.isGranted) return 'Granted';
    if (s.isLimited) return 'Limited';
    if (s.isDenied) return 'Denied';
    if (s.isPermanentlyDenied) return 'Blocked';
    return 'Unknown';
  }
}
