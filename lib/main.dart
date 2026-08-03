import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/bootstrap/bootstrap_controller.dart';
import 'package:mynotes/core/bootstrap/bootstrap_error_view.dart';
import 'package:mynotes/core/bootstrap/bootstrap_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: BootstrapApp(),
    ),
  );
}

/// Boots Firebase and the app engine, then shows the app, a loading state, or
/// a retryable error screen.
class BootstrapApp extends ConsumerStatefulWidget {
  const BootstrapApp({super.key});

  @override
  ConsumerState<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends ConsumerState<BootstrapApp> {
  @override
  void initState() {
    super.initState();
    ref.read(bootstrapControllerProvider).bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(bootstrapControllerProvider);
    return switch (controller.status) {
      BootstrapStatus.ready => LiquidGlassWidgets.wrap(
          child: const MyApp(),
          theme: notelyGlassTheme,
        ),
      BootstrapStatus.initializing => const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        ),
      BootstrapStatus.failed => BootstrapErrorView(
          message: controller.errorMessage,
          onRetry: () => ref.read(bootstrapControllerProvider).bootstrap(),
        ),
    };
  }
}
