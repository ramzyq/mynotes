import 'package:shared_preferences/shared_preferences.dart';

class PendingLinkStore {
  static const String _key = 'pending_join_link';
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _instance() async =>
      _prefs ??= await SharedPreferences.getInstance();

  static Future<void> save(String url) async {
    final prefs = await _instance();
    await prefs.setString(_key, url);
  }

  static Future<String?> read() async => (await _instance()).getString(_key);

  static Future<void> clear() async {
    final prefs = await _instance();
    await prefs.remove(_key);
  }
}
