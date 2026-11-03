import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Thin abstraction over analytics so tests can inject a fake.
abstract class AnalyticsService {
  Future<void> setCollectionEnabled(bool enabled);
}

class FirebaseAnalyticsService implements AnalyticsService {
  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
    // Crash reports follow the same opt-in as usage analytics. They carry
    // stack traces only, never note contents (which are encrypted anyway).
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
  }
}
