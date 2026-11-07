import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart';
import 'package:mynotes/core/theme/widgets/async_states.dart';
import 'package:mynotes/core/deeplinks/incoming_links.dart';
import 'package:mynotes/core/encryption/presentation/key_setup_gate.dart';
import 'package:mynotes/core/encryption/providers/encryption_providers.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/core/providers/theme_mode_provider.dart';
import 'package:mynotes/core/theme/notely_theme.dart';
import 'package:mynotes/core/theme/widgets/notely_dialog.dart';
import 'package:mynotes/features/auth/presentation/forgot_password_view.dart';
import 'package:mynotes/features/auth/presentation/login_view.dart';
import 'package:mynotes/features/auth/presentation/verify_email_view.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/features/notes/presentation/notes_home_view.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';

export 'package:mynotes/core/theme/notely_theme.dart';

/// Lets links that arrive at any time open a screen or show a message,
/// whatever is on screen.
final appNavigatorKey = GlobalKey<NavigatorState>();
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  // The saved theme is restored during bootstrap, before this first builds.
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appMessengerKey,
      title: 'Notely',
      theme: buildNotelyTheme(Brightness.light),
      darkTheme: buildNotelyTheme(Brightness.dark),
      themeMode: themeMode,
      home: const AuthenticationWrapper(),
    );
  }
}

class AuthenticationWrapper extends ConsumerStatefulWidget {
  const AuthenticationWrapper({super.key});

  @override
  ConsumerState<AuthenticationWrapper> createState() => _AuthenticationWrapperState();
}

class _AuthenticationWrapperState extends ConsumerState<AuthenticationWrapper>
    with WidgetsBindingObserver {
  // Expired notes are deleted when the app returns to the foreground, at the
  // exact expiry time while the notes list is open (NotesHomeView), and
  // hourly by the server job (.github/workflows/expire-notes.yml). No polling.

  StreamSubscription<Uri>? _links;

  /// A reset screen opened from a link is showing: further links (e.g. the
  /// same one twice) don't stack more screens.
  bool _resetFromLinkOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Listened to here, above sign-in, so a link that arrives (or launches
    // the app) while signed out is not lost: share links are kept until
    // sign-in, and reset links are for signed-out users anyway.
    _links = ref.read(incomingLinksProvider).listen(_openLink, onError: AppErrorHandler().handle);
  }

  Future<void> _openLink(Uri uri) async {
    switch (IncomingLink.parse(uri)) {
      case PasswordResetIncomingLink(:final uri):
        if (_resetFromLinkOpen) return;
        _resetFromLinkOpen = true;
        // A link that launched the app can arrive before the first frame,
        // when there is no navigator to push onto yet.
        await WidgetsBinding.instance.endOfFrame;
        final String? email;
        try {
          email = await appNavigatorKey.currentState?.push<String>(MaterialPageRoute(
            builder: (_) => ForgotPasswordView(initialLink: uri.toString()),
          ));
        } finally {
          _resetFromLinkOpen = false;
        }
        if (email != null) {
          appMessengerKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Password changed. Sign in with your new password.')),
          );
        }
      case JoinIncomingLink(:final uri):
        await ref.read(joinLinkProcessorProvider).handleUri(uri).catchError(AppErrorHandler().handle);
      case VerifyEmailIncomingLink(:final code):
        await _verifyEmail(code);
      case RecoverEmailIncomingLink(:final code):
        await _recoverEmail(code);
      case ChangeEmailIncomingLink():
        _tell("Notely doesn't support changing your account email yet, so this link wasn't used.");
      case UnsupportedEmailActionIncomingLink(:final uri):
        // Lasts until dismissed: copying the link is the only way forward.
        appMessengerKey.currentState?.showSnackBar(SnackBar(
          content: const Text("Notely can't handle this link. Copy it and open it in a browser."),
          duration: const Duration(days: 1),
          showCloseIcon: true,
          action: SnackBarAction(
            label: 'Copy link',
            onPressed: () => Clipboard.setData(ClipboardData(text: uri.toString())),
          ),
        ));
      case null:
        break;
    }
  }

  void _tell(String message) =>
      appMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(message)));

  /// Sign-in state restored, so `currentUser` is meaningful. A link that
  /// launched the app can arrive before that.
  Future<void> _authReady() async {
    try {
      await ref.read(authStateProvider.future).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Proceed without it; the verify screen's own check catches up.
    }
  }

  static bool _sameEmail(String? a, String? b) =>
      a != null && b != null && a.trim().toLowerCase() == b.trim().toLowerCase();

  String _linkErrorMessage(Object error) => switch (error) {
        InvalidActionCodeAuthException() =>
          "This link has expired or was already used. If you still need it, request a new one from Notely.",
        NetworkAuthException() => "You're offline. Open the link again once you're connected.",
        TooManyRequestsAuthException() => 'Too many attempts. Try the link again in a few minutes.',
        _ => "That didn't work. Try the link again.",
      };

  /// Apply a verification link. The link may be for another account than
  /// the one signed in here, so check first and say what actually happened.
  Future<void> _verifyEmail(String code) async {
    await _authReady();
    final auth = ref.read(authServiceProvider);
    final current = auth.currentUser;
    String? linkEmail;
    try {
      linkEmail = (await auth.checkActionCode(code)).email;
      await auth.applyActionCode(code);
    } on InvalidActionCodeAuthException {
      // Often a second tap on a link that already worked.
      final mine = linkEmail == null || _sameEmail(linkEmail, current?.email);
      _tell(mine && (current?.isEmailVerified ?? false)
          ? 'Your email is already verified.'
          : _linkErrorMessage(InvalidActionCodeAuthException()));
      return;
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      _tell(_linkErrorMessage(error));
      return;
    }

    if (current == null) {
      _tell('Email verified. Sign in to continue.');
      return;
    }
    if (linkEmail != null && !_sameEmail(linkEmail, current.email)) {
      _tell('Verified $linkEmail. Sign in with that account to use it.');
      return;
    }
    try {
      await auth.reloadCurrentUser();
      _tell('Email verified.');
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      _tell('Email verified. Notely continues as soon as it reconnects.');
    }
  }

  /// "This wasn't me": restore the account's previous email after the user
  /// confirms, since it changes which address signs in.
  Future<void> _recoverEmail(String code) async {
    await _authReady();
    final auth = ref.read(authServiceProvider);
    final String? restored;
    try {
      restored = (await auth.checkActionCode(code)).email;
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      _tell(_linkErrorMessage(error));
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    final context = appNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final confirmed = await showNotelyDialog<bool>(
      context: context,
      title: 'Undo the email change?',
      message: restored == null
          ? "Your account's email goes back to what it was before."
          : "Your account's email goes back to $restored.",
      actions: [
        NotelyDialogAction(label: 'Cancel', onPressed: () => Navigator.of(context).pop(false)),
        NotelyDialogAction(label: 'Undo change', isPrimary: true, onPressed: () => Navigator.of(context).pop(true)),
      ],
    );
    if (confirmed != true) return;
    try {
      await auth.applyActionCode(code);
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      _tell(_linkErrorMessage(error));
      return;
    }
    _tell("Your email change was undone. If you didn't make it, reset your password now.");
  }

  @override
  void dispose() {
    _links?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cleanupExpiredNotes();
    }
  }

  void _cleanupExpiredNotes() {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    ref
        .read(notesServiceProvider)
        .deleteExpiredNotes(user.uid)
        .catchError(AppErrorHandler().handle);
  }

  @override
  Widget build(BuildContext context) {
    // Drop all key material and decrypted caches when the user changes.
    ref.listen(authStateProvider, (previous, next) {
      final previousUid = previous?.valueOrNull?.uid;
      final uid = next.valueOrNull?.uid;
      if (previousUid == uid) return;
      ref.read(keyManagerProvider).setActiveUser(uid);
      ref.read(notesServiceProvider).clearCaches();
      if (uid == null) ref.read(pendingPasswordKeyProvider.notifier).state = null;
    });
    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (user) {
        if (user != null) {
          if (user.isEmailVerified) {
            return KeySetupGate(
              key: ValueKey(user.uid),
              authUser: user,
              child: NotesHomeView(authUser: user),
            );
          }
          return const VerifyEmailView();
        }
        return const LoginView();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: ErrorState(
          title: "Couldn't check your sign-in",
          error: error,
          onRetry: () => ref.invalidate(authStateProvider),
        ),
      ),
    );
  }
}
