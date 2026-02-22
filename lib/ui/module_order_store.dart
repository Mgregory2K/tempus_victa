import 'package:shared_preferences/shared_preferences.dart';

class ModuleOrderStore {
  static const String _kKey = 'tempus.module_order.v1';

  static Future<List<String>?> loadOrderIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_kKey);
    if (ids == null || ids.isEmpty) return null;
    return ids;
  }

  static Future<void> saveOrderIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kKey, ids);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}