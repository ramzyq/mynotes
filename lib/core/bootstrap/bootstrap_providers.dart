import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mynotes/core/analytics/analytics_service.dart';
import 'package:mynotes/core/analytics/consent_coordinator.dart';
import 'package:mynotes/core/bootstrap/bootstrap_controller.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/core/providers/theme_mode_provider.dart';
import 'package:mynotes/firebase_options.dart';

/// Initializes Firebase, the glass engine, the error handler, and applies the
/// stored analytics consent. Runs once at app start.
final bootstrapControllerProvider =
    ChangeNotifierProvider<BootstrapController>((ref) {
  return BootstrapController(
    initialize: () async {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await LiquidGlassWidgets.initialize();
      // Load the saved theme before the app's first frame, so it never
      // flashes the system theme first.
      await ref.read(themeModeProvider.notifier).restore();
      AppErrorHandler()
        ..onError = (error, stack) {
          // A no-op while collection is disabled (no consent yet).
          FirebaseCrashlytics.instance.recordError(error, stack).ignore();
        }
        ..init();
      await ConsentCoordinator(analytics: FirebaseAnalyticsService())
          .applyStartupConsent();
    },
  );
});
