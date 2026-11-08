import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/bootstrap/bootstrap_controller.dart';
import 'package:mynotes/core/bootstrap/bootstrap_error_view.dart';
import 'package:mynotes/core/bootstrap/bootstrap_providers.dart';
import 'package:mynotes/core/bootstrap/splash_view.dart';
import 'package:mynotes/core/providers/theme_mode_provider.dart';
import 'package:mynotes/core/theme/notely_motion.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The splash paints before bootstrap restores the saved theme, so read it
  // here: someone who chose Light on a dark-mode phone gets a light splash.
  final splashTheme = await readSavedThemeMode();
  runApp(ProviderScope(child: BootstrapApp(splashTheme: splashTheme)));
}

/// Plays the splash while Firebase and the app engine boot, then fades into
/// the app or a retryable error screen.
class BootstrapApp extends ConsumerStatefulWidget {
  final ThemeMode splashTheme;

  const BootstrapApp({super.key, this.splashTheme = ThemeMode.system});

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
    // Started just after this build: bootstrap notifies its listeners
    // straight away, which Riverpod refuses in the middle of a build.
    Future.microtask(() => ref.read(bootstrapControllerProvider).bootstrap());
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(bootstrapControllerProvider);
    final Widget child;
    if (_splashDone && controller.status == BootstrapStatus.ready) {
      child = KeyedSubtree(
        key: const ValueKey('app'),
        child: LiquidGlassWidgets.wrap(child: const MyApp(), theme: notelyGlassTheme),
      );
    } else if (_splashDone && controller.status == BootstrapStatus.failed) {
      child = KeyedSubtree(
        key: const ValueKey('error'),
        child: BootstrapErrorView(
          message: controller.errorMessage,
          onRetry: () => ref.read(bootstrapControllerProvider).bootstrap(),
        ),
      );
    } else if (_splashDone) {
      // Retrying after a failed start: plain paper, not the splash again
      // (a fast retry would otherwise cut a replayed splash off mid-way).
      child = _plainApp(const ValueKey('retrying'), const Scaffold(body: SizedBox.expand()));
    } else {
      child = _plainApp(const ValueKey('splash'), SplashView(onFinished: () => setState(() => _splashDone = true)));
    }
    // Above any MediaQuery, so ask the platform about reduce motion directly.
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final reduceMotion = dispatcher.accessibilityFeatures.disableAnimations;
    final dark = switch (widget.splashTheme) {
      ThemeMode.light => false,
      ThemeMode.dark => true,
      ThemeMode.system => dispatcher.platformBrightness == Brightness.dark,
    };
    // Paper behind the cross-fade: mid-fade both screens are partly
    // transparent, and the bare window underneath would flash black.
    return ColoredBox(
      color: dark ? SplashView.night : SplashView.paper,
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 450),
        switchInCurve: NotelyMotion.enter,
        switchOutCurve: NotelyMotion.exit,
        child: child,
      ),
    );
  }

  Widget _plainApp(Key key, Widget home) => MaterialApp(
    key: key,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: SplashView.paper),
    darkTheme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: SplashView.night),
    themeMode: widget.splashTheme,
    home: home,
  );
}
