import 'package:firebase_analytics/firebase_analytics.dart';

/// Thin abstraction over analytics so tests can inject a fake.
abstract class AnalyticsService {
  Future<void> setCollectionEnabled(bool enabled);
}

class FirebaseAnalyticsService implements AnalyticsService {
  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
  }
}
