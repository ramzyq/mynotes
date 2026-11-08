import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/bootstrap/splash_view.dart';
import 'package:mynotes/core/theme/notely_theme.dart';
import 'package:mynotes/core/theme/widgets/notely_mark.dart';
import 'package:mynotes/features/onboarding/onboarding_store.dart';
import 'package:mynotes/features/onboarding/presentation/welcome_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home, {bool reduceMotion = false}) => MaterialApp(
  theme: buildNotelyTheme(Brightness.light),
  home: MediaQuery(
    data: MediaQueryData(size: const Size(390, 844), disableAnimations: reduceMotion),
    child: home,
  ),
);

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('onboarding flag', () {
    test('a new install has not seen the welcome pages; completing remembers it', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = OnboardingController();
      expect(controller.state, isTrue, reason: 'nothing shows them before restore');
      await controller.restore();
      expect(controller.state, isFalse);
      await controller.complete();
      expect(controller.state, isTrue);
      final again = OnboardingController();
      await again.restore();
      expect(again.state, isTrue);
    });
  });

  group('WelcomeView', () {
    testWidgets('Next walks the pages, and Get started asks to create an account', (tester) async {
      bool? createAccount;
      await tester.pumpWidget(_app(WelcomeView(onFinish: (value) => createAccount = value)));
      await tester.pumpAndSettle();
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Get started'), findsNothing);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
      await tester.tap(find.text('Get started'));
      expect(createAccount, isTrue);
    });

    testWidgets('Skip jumps to the last page; the sign-in link asks for sign-in', (tester) async {
      bool? createAccount;
      await tester.pumpWidget(_app(WelcomeView(onFinish: (value) => createAccount = value)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I already have an account'));
      expect(createAccount, isFalse);
    });

    testWidgets('fits a small phone on every page', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpWidget(_app(WelcomeView(onFinish: (_) {})));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Get started'), findsOneWidget);
    });

    testWidgets('works with reduce motion on', (tester) async {
      await tester.pumpWidget(_app(WelcomeView(onFinish: (_) {}), reduceMotion: true));
      await tester.pump();
      expect(find.textContaining('Every note is locked'), findsOneWidget);
    });
  });

  group('SplashView', () {
    testWidgets('finishes after its animation', (tester) async {
      var finished = false;
      await tester.pumpWidget(_app(SplashView(onFinished: () => finished = true)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(finished, isFalse);
      await tester.pump(SplashView.duration);
      expect(finished, isTrue);
      expect(find.byType(NotelyMark), findsOneWidget);
      expect(find.text('Notely'), findsOneWidget);
    });

    testWidgets('finishes straight away under reduce motion', (tester) async {
      var finished = false;
      await tester.pumpWidget(_app(SplashView(onFinished: () => finished = true), reduceMotion: true));
      await tester.pump();
      expect(finished, isTrue);
    });
  });
}
