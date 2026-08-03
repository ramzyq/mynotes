import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's analytics consent decision.
///
/// null = undecided (collection stays disabled), true = granted,
/// false = denied.
class AnalyticsConsentStore {
  static const String _key = 'analytics_consent';
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _instance() async =>
      _prefs ??= await SharedPreferences.getInstance();

  static Future<bool?> read() async => (await _instance()).getBool(_key);

  static Future<void> save(bool value) async {
    await (await _instance()).setBool(_key, value);
  }
}
