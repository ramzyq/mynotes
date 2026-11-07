import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/bootstrap/bootstrap_controller.dart';
import 'package:mynotes/core/bootstrap/bootstrap_error_view.dart';
import 'package:mynotes/core/bootstrap/bootstrap_providers.dart';
import 'package:mynotes/core/bootstrap/splash_view.dart';
import 'package:mynotes/core/theme/notely_motion.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: BootstrapApp(),
    ),
  );
}

/// Plays the splash while Firebase and the app engine boot, then fades into
/// the app or a retryable error screen.
class BootstrapApp extends ConsumerStatefulWidget {
  const BootstrapApp({super.key});

  @override
  ConsumerState<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends ConsumerState<BootstrapApp> {
  // The splash always plays to the end before the app (or the error screen)
  // replaces it, so a fast boot never cuts the animation off mid-way.
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    ref.read(bootstrapControllerProvider).bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(bootstrapControllerProvider);
    final Widget child;
    if (_splashDone && controller.status == BootstrapStatus.ready) {
      child = KeyedSubtree(
        key: const ValueKey('app'),
        child: LiquidGlassWidgets.wrap(
          child: const MyApp(),
          theme: notelyGlassTheme,
        ),
      );
    } else if (_splashDone && controller.status == BootstrapStatus.failed) {
      child = KeyedSubtree(
        key: const ValueKey('error'),
        child: BootstrapErrorView(
          message: controller.errorMessage,
          onRetry: () => ref.read(bootstrapControllerProvider).bootstrap(),
        ),
      );
    } else {
      child = MaterialApp(
        key: const ValueKey('splash'),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.light),
        darkTheme: ThemeData(brightness: Brightness.dark),
        home: SplashView(onFinished: () => setState(() => _splashDone = true)),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: NotelyMotion.enter,
      switchOutCurve: NotelyMotion.exit,
      child: child,
    );
  }
}
