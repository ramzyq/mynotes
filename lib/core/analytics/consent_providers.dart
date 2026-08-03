import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/analytics/analytics_consent_store.dart';
import 'package:mynotes/core/analytics/analytics_service.dart';
import 'package:mynotes/core/analytics/consent_coordinator.dart';

final consentCoordinatorProvider = Provider<ConsentCoordinator>((ref) {
  return ConsentCoordinator(analytics: FirebaseAnalyticsService());
});

/// Current analytics consent: null = undecided, true = granted, false = denied.
final consentStatusProvider = FutureProvider<bool?>((ref) {
  return AnalyticsConsentStore.read();
});
