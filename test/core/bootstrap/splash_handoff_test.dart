import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/bootstrap/bootstrap_controller.dart';
import 'package:mynotes/core/bootstrap/bootstrap_providers.dart';
import 'package:mynotes/core/bootstrap/splash_view.dart';
import 'package:mynotes/main.dart';

void main() {
  testWidgets('the splash plays out before a failure shows; a retry does not replay it', (tester) async {
    var attempts = 0;
    final retry = Completer<void>();
    final controller = BootstrapController(initialize: () async {
      attempts++;
      if (attempts == 1) throw Exception('offline');
      await retry.future;
      throw Exception('still offline');
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [bootstrapControllerProvider.overrideWith((ref) => controller)],
      child: const BootstrapApp(),
    ));

    // Boot fails at once, but the splash still finishes first.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SplashView), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);

    // Retrying shows plain paper, not the splash again.
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byType(SplashView), findsNothing);
    expect(find.text('Try again'), findsNothing);

    retry.complete();
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(attempts, 2);
  });
}
