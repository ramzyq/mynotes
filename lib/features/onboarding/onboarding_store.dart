import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers that this device has seen the welcome pages, so they show once.
class OnboardingStore {
  static const String _key = 'onboarding_seen';

  static Future<bool> read() async => (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  static Future<void> markSeen() async => (await SharedPreferences.getInstance()).setBool(_key, true);
}

/// Whether to skip the welcome pages. Starts true so nothing shows them by
/// accident; [OnboardingController.restore] (run during bootstrap) loads the
/// real value before the first screen.
class OnboardingController extends StateNotifier<bool> {
  OnboardingController() : super(true);

  Future<void> restore() async {
    state = await OnboardingStore.read();
  }

  Future<void> complete() async {
    state = true;
    await OnboardingStore.markSeen();
  }
}

final onboardingSeenProvider = StateNotifierProvider<OnboardingController, bool>((ref) => OnboardingController());
