import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/theme/widgets/async_states.dart';
import 'package:mynotes/core/deeplinks/incoming_links.dart';
import 'package:mynotes/core/encryption/presentation/key_setup_gate.dart';
import 'package:mynotes/core/encryption/providers/encryption_providers.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/core/providers/theme_mode_provider.dart';
import 'package:mynotes/core/theme/notely_theme.dart';
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
        final email = await appNavigatorKey.currentState?.push<String>(MaterialPageRoute(
          builder: (_) => ForgotPasswordView(initialLink: uri.toString()),
        ));
        if (email != null) {
          appMessengerKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Password changed. Sign in with your new password.')),
          );
        }
      case JoinIncomingLink(:final uri):
        await ref.read(joinLinkProcessorProvider).handleUri(uri).catchError(AppErrorHandler().handle);
      case null:
        break;
    }
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
