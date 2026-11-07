// Temporary: reproduce the startup '!_dirty' assertion. Not committed.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';

void main() {
  testWidgets('signed-out app starts on the sign-in screen', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [authStateProvider.overrideWith((ref) => Stream<AuthUser?>.value(null))],
      child: LiquidGlassWidgets.wrap(child: const MyApp(), theme: notelyGlassTheme),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
  });
}
