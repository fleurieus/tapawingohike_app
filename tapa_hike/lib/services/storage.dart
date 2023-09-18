import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  // Deze methode slaat een String-waarde op in lokale opslag.
  static Future<void> saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  // Deze methode haalt een opgeslagen String-waarde op uit lokale opslag.
  static Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  // Deze methode verwijdert een opgeslagen waarde uit lokale opslag.
  static Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
