import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mynotes/core/analytics/analytics_consent_store.dart';
import 'package:mynotes/core/analytics/analytics_service.dart';
import 'package:mynotes/core/analytics/consent_coordinator.dart';

class _FakeAnalyticsService implements AnalyticsService {
  bool? lastEnabled;

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    lastEnabled = enabled;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AnalyticsConsentStore', () {
    test('returns null when undecided', () async {
      expect(await AnalyticsConsentStore.read(), isNull);
    });

    test('persists granted decision', () async {
      await AnalyticsConsentStore.save(true);
      expect(await AnalyticsConsentStore.read(), isTrue);
    });

    test('persists denied decision', () async {
      await AnalyticsConsentStore.save(false);
      expect(await AnalyticsConsentStore.read(), isFalse);
    });
  });

  group('ConsentCoordinator', () {
    test('undecided consent disables collection on startup', () async {
      final analytics = _FakeAnalyticsService();
      final coordinator = ConsentCoordinator(analytics: analytics);
      await coordinator.applyStartupConsent();
      expect(analytics.lastEnabled, isFalse);
    });

    test('granted consent enables collection on startup', () async {
      await AnalyticsConsentStore.save(true);
      final analytics = _FakeAnalyticsService();
      final coordinator = ConsentCoordinator(analytics: analytics);
      await coordinator.applyStartupConsent();
      expect(analytics.lastEnabled, isTrue);
    });

    test('denied consent keeps collection disabled on startup', () async {
      await AnalyticsConsentStore.save(false);
      final analytics = _FakeAnalyticsService();
      final coordinator = ConsentCoordinator(analytics: analytics);
      await coordinator.applyStartupConsent();
      expect(analytics.lastEnabled, isFalse);
    });

    test('recordDecision persists and applies the choice', () async {
      final analytics = _FakeAnalyticsService();
      final coordinator = ConsentCoordinator(analytics: analytics);
      await coordinator.recordDecision(false);
      expect(await AnalyticsConsentStore.read(), isFalse);
      expect(analytics.lastEnabled, isFalse);

      await coordinator.recordDecision(true);
      expect(await AnalyticsConsentStore.read(), isTrue);
      expect(analytics.lastEnabled, isTrue);
    });
  });
}
