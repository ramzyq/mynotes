import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mynotes/features/auth/presentation/login_view.dart';
import 'package:mynotes/features/auth/presentation/verify_email_view.dart';
import 'package:mynotes/firebase_options.dart';
import 'package:mynotes/core/auth/services/auth_service.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/features/notes/presentation/notes_home_view.dart';
import 'package:mynotes/widgets/theme_toggle_button.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  final AuthService? authService;

  const MyApp({super.key, this.authService});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = true;

  void _toggleTheme() {
    setState(() => _isDarkMode = !_isDarkMode);
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF0B0F1A) : const Color(0xFFF5F7FB);
    final surface = isDark ? const Color(0xFF121826) : const Color(0xFFFFFFFF);
    final card = isDark ? const Color(0xFF141B2D) : const Color(0xFFF0F3FA);
    final onSurface = isDark ? const Color(0xFFF4F7FB) : const Color(0xFF121826);
    final outline = isDark ? const Color(0xFF27314A) : const Color(0xFFD5DCEB);
    final accent = isDark ? const Color(0xFF86E7C8) : const Color(0xFF0C8B6A);

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: brightness,
        surface: surface,
      ).copyWith(
        primary: accent,
        secondary: isDark ? const Color(0xFF8AA7FF) : const Color(0xFF4D6BFF),
        surface: surface,
        onSurface: onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: accent, width: 1.4),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveAuthService = widget.authService ?? AuthService.firebase();

    return AppThemeScope(
      isDarkMode: _isDarkMode,
      toggleTheme: _toggleTheme,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Note Log',
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
        home: AuthenticationWrapper(authService: effectiveAuthService),
      ),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  final AuthService authService;

  const AuthenticationWrapper({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthUser?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final authUser = snapshot.data;
        if (authUser != null) {
          if (authUser.isEmailVerified) {
            return NotesHomeView(authService: authService, authUser: authUser);
          } else {
            return VerifyEmailView(authService: authService);
          }
        } else {
          return LoginView(authService: authService);
        }
      },
    );
  }
}
