import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart';
import 'package:mynotes/core/theme/widgets/notely_buttons.dart';
import 'package:mynotes/features/account/presentation/delete_account_view.dart';
import 'package:mynotes/features/account/providers/account_providers.dart';
import 'package:mynotes/features/account/services/account_deletion_service.dart';

class _MockDeletion extends Mock implements AccountDeletionService {}

const _user = AuthUser(uid: 'u1', email: 'maya@example.com', isEmailVerified: true, hasPassword: true);

void main() {
  late _MockDeletion deletion;

  setUpAll(() => registerFallbackValue(_user));
  setUp(() => deletion = _MockDeletion());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [accountDeletionServiceProvider.overrideWithValue(deletion)],
      child: MaterialApp(theme: buildNotelyTheme(Brightness.light), home: const DeleteAccountView(authUser: _user)),
    ));
  }

  NotelyPrimaryButton button(WidgetTester tester) => tester.widget(find.byType(NotelyPrimaryButton));

  testWidgets('stays disabled until DELETE is typed', (tester) async {
    await open(tester);
    expect(button(tester).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Type DELETE to confirm'), 'delet');
    await tester.pump();
    expect(button(tester).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Type DELETE to confirm'), 'delete');
    await tester.pump();
    expect(button(tester).onPressed, isNotNull, reason: 'case does not matter');
  });

  testWidgets('a wrong password keeps the screen open and says so', (tester) async {
    when(() => deletion.deleteAccount(user: any(named: 'user'), password: any(named: 'password')))
        .thenThrow(WrongPasswordAuthException());
    await open(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Your password'), 'not it');
    await tester.enterText(find.widgetWithText(TextField, 'Type DELETE to confirm'), 'DELETE');
    await tester.pump();
    await tester.ensureVisible(find.text('Delete my account'));
    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();

    expect(find.text("That password isn't right."), findsOneWidget);
    expect(find.text('Delete your account?'), findsOneWidget);
    verify(() => deletion.deleteAccount(user: _user, password: 'not it')).called(1);
  });
}
