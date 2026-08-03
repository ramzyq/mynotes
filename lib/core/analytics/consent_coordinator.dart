import 'package:mynotes/core/analytics/analytics_consent_store.dart';
import 'package:mynotes/core/analytics/analytics_service.dart';

/// Applies the user's analytics consent decision. Collection is only enabled
/// after explicit opt-in.
class ConsentCoordinator {
  final AnalyticsService analytics;

  ConsentCoordinator({required this.analytics});

  /// Called once at app start. Disables collection until consent is granted.
  Future<void> applyStartupConsent() async {
    final consent = await AnalyticsConsentStore.read();
    await analytics.setCollectionEnabled(consent == true);
  }

  /// Persists the decision and immediately applies it.
  Future<void> recordDecision(bool granted) async {
    await AnalyticsConsentStore.save(granted);
    await analytics.setCollectionEnabled(granted);
  }
}
