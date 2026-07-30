# Phase 0: Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the codebase into feature folders, add Riverpod for state management + DI, add drift for local database (offline + FTS5), add flutter_secure_storage for key material, and centralize error handling.

**Architecture:** Flat folder → feature-based structure with `core/` for shared infrastructure and `features/` for feature modules. Riverpod providers replace static factories and `setState`/`StreamBuilder` for auth and notes state.

**Tech Stack:** flutter_riverpod, drift (SQLite + FTS5), flutter_secure_storage, path_provider, flutter_lints

---

## File Structure Map

### New files to create:
- `lib/core/providers/providers.dart` — global Riverpod providers
- `lib/core/db/local_database.dart` — drift database definition
- `lib/core/db/app_database.dart` — drift database class with FTS5
- `lib/core/error/error_handler.dart` — global error handler + crash reporting stub
- `lib/app.dart` — `MyApp` widget extracted from `main.dart`
- `lib/features/auth/providers/auth_providers.dart` — auth state providers
- `lib/features/notes/providers/notes_providers.dart` — notes state providers
- `lib/features/notes/data/notes_repository.dart` — repository wrapping notes_service

### Files to modify:
- `lib/main.dart` — slim down to just initialization + runApp
- `lib/views/login_view.dart` — adopt Riverpod providers
- `lib/views/register_view.dart` — adopt Riverpod providers
- `lib/views/verify_email_view.dart` — adopt Riverpod providers
- `lib/views/notes_home_view.dart` — adopt Riverpod providers
- `lib/views/note_editor_view.dart` — adopt Riverpod providers
- `lib/widgets/theme_toggle_button.dart` — adopt Riverpod for theme state

### Files to move (no logic change):
- `lib/services/auth/auth_user.dart` → `lib/core/auth/models/auth_user.dart`
- `lib/services/auth/auth_exceptions.dart` → `lib/core/auth/services/auth_exceptions.dart`
- `lib/services/auth/auth_provider.dart` → `lib/core/auth/services/auth_provider.dart`
- `lib/services/auth/auth_services.dart` → `lib/core/auth/services/auth_service.dart`
- `lib/services/auth/firebase_auth_provider.dart` → `lib/core/auth/services/firebase_auth_provider.dart`
- `lib/services/notes/note.dart` → `lib/features/notes/data/note.dart`
- `lib/services/notes/notes_service.dart` → `lib/features/notes/data/notes_service.dart`

### Files to delete:
- `lib/services/` (after all files moved)

### Test files to create/update:
- `test/core/auth/providers/auth_providers_test.dart`
- `test/features/notes/providers/notes_providers_test.dart`
- `test/core/error/error_handler_test.dart`

---

## Global Constraints

- All existing Firebase functionality must continue working after each task — no regressions.
- `flutter analyze` must pass with no issues after each task.
- `flutter test` must pass after each task.
- Follow existing code style (no comments in production code, use `const` where possible).
- Use Riverpod `ref.watch` / `ref.read` — NOT `context.watch` / `context.read`.
- Riverpod providers go in `lib/.../providers/` directories.
- Drift tables go in `lib/core/db/`.
- Feature views go in `lib/features/<feature>/presentation/`.

---

### Task 1: Add dependencies and create provider scaffold

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/providers/providers.dart`

**Interfaces:**
- Consumes: none
- Produces: `pubspec.yaml` with new deps, empty providers file

- [ ] **Step 1: Update pubspec.yaml**

```yaml
dependencies:
  flutter_riverpod: ^2.6.1
  drift: ^2.25.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.5
  path: ^1.9.1
  flutter_secure_storage: ^9.2.4

dev_dependencies:
  drift_dev: ^2.25.0
  build_runner: ^2.4.0
```

- [ ] **Step 2: Run pub get**

```
flutter pub get
```

- [ ] **Step 3: Create provider scaffold**

Create `lib/core/providers/providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Placeholder — will be populated as tasks progress
```

- [ ] **Step 4: Run analyze + tests to verify no regressions**

```
flutter analyze
flutter test
```

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/providers/providers.dart
git commit -m "chore: add flutter_riverpod, drift, flutter_secure_storage deps"
```

---

### Task 2: Move auth files to core/auth/services/

**Files:**
- Move: `lib/services/auth/auth_user.dart` → `lib/core/auth/models/auth_user.dart`
- Move: `lib/services/auth/auth_exceptions.dart` → `lib/core/auth/services/auth_exceptions.dart`
- Move: `lib/services/auth/auth_provider.dart` → `lib/core/auth/services/auth_provider.dart`
- Move: `lib/services/auth/auth_services.dart` → `lib/core/auth/services/auth_service.dart`
- Move: `lib/services/auth/firebase_auth_provider.dart` → `lib/core/auth/services/firebase_auth_provider.dart`
- Modify: All files that import the old paths

- [ ] **Step 1: Create target directories**

```bash
mkdir -p lib/core/auth/models
mkdir -p lib/core/auth/services
```

- [ ] **Step 2: Move and update imports in each file**

Move each file, update its internal imports to match new relative paths.

For `auth_service.dart` (renamed from `auth_services.dart`):
```dart
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/services/auth_provider.dart';
import 'package:mynotes/core/auth/services/firebase_auth_provider.dart';
```

For `firebase_auth_provider.dart`:
```dart
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/services/auth_exceptions.dart';
import 'package:mynotes/core/auth/services/auth_provider.dart';
```

- [ ] **Step 3: Update all imports in views and main.dart**

The following files import from `package:mynotes/services/auth/...`:
- `lib/main.dart`
- `lib/views/login_view.dart`
- `lib/views/register_view.dart`
- `lib/views/verify_email_view.dart`
- `lib/views/notes_home_view.dart`

Update each to use `package:mynotes/core/auth/...` paths.

- [ ] **Step 4: Update widget_test.dart**

`test/widget_test.dart` imports from `lib/services/auth/...` — update to new paths.

- [ ] **Step 5: Remove old services/auth/ directory**

```bash
Remove-Item -Recurse -Force lib/services/auth
```

If `lib/services/` is now empty, remove it too.

- [ ] **Step 6: Run analyze + tests**

```
flutter analyze
flutter test
```

- [ ] **Step 7: Commit**

```bash
git add lib/core/auth/ lib/views/ lib/main.dart test/
git add -u  # track moves
git commit -m "refactor: move auth files to core/auth/services/"
```

---

### Task 3: Move note files to features/notes/

**Files:**
- Move: `lib/services/notes/note.dart` → `lib/features/notes/data/note.dart`
- Move: `lib/services/notes/notes_service.dart` → `lib/features/notes/data/notes_service.dart`
- Move: `lib/views/notes_home_view.dart` → `lib/features/notes/presentation/notes_home_view.dart`
- Move: `lib/views/note_editor_view.dart` → `lib/features/notes/presentation/note_editor_view.dart`
- Create: `lib/features/notes/presentation/widgets/` — for _InfoChip, _TagChip, _EmptyNotesState (extracted from notes_home_view.dart)

- [ ] **Step 1: Create directories**

```bash
mkdir -p lib/features/notes/data
mkdir -p lib/features/notes/presentation
mkdir -p lib/features/notes/presentation/widgets
```

- [ ] **Step 2: Move note.dart and notes_service.dart**

Update imports:
- `notes_service.dart` imports `note.dart` — update path
- `note_editor_view.dart` imports from `services/notes/` — update
- `notes_home_view.dart` imports from `services/notes/` — update
- `main.dart` imports from `views/notes_home_view.dart` — update

- [ ] **Step 3: Move note_editor_view.dart and notes_home_view.dart**

Update all cross-imports between these files.

- [ ] **Step 4: Extract private widgets from notes_home_view.dart**

`_InfoChip`, `_TagChip`, and `_EmptyNotesState` are currently private classes in `notes_home_view.dart`. Extract them to separate files in `lib/features/notes/presentation/widgets/`:

- `info_chip.dart`
- `tag_chip.dart`
- `empty_notes_state.dart`

Make them public (remove underscore prefix in class names). Update imports in `notes_home_view.dart`.

```dart
// info_chip.dart
class InfoChip extends StatelessWidget { ... }

// tag_chip.dart
class TagChip extends StatelessWidget { ... }

// empty_notes_state.dart
class EmptyNotesState extends StatelessWidget { ... }
```

- [ ] **Step 5: Remove old files**

```bash
Remove-Item -Recurse -Force lib/services/notes
Remove-Item -Recurse -Force lib/services
Remove-Item lib/views/notes_home_view.dart
Remove-Item lib/views/note_editor_view.dart
```

- [ ] **Step 6: Run analyze + tests**

```
flutter analyze
flutter test
```

- [ ] **Step 7: Commit**

```bash
git add lib/features/notes/
git add -u
git commit -m "refactor: move notes to features/notes/ with extracted widgets"
```

---

### Task 4: Set up drift local database

**Files:**
- Create: `lib/core/db/app_database.dart`
- Create: `lib/core/db/tables.dart`
- Modify: `lib/core/providers/providers.dart` — add database provider

- [ ] **Step 1: Create database tables definition**

`lib/core/db/tables.dart`:

```dart
import 'package:drift/drift.dart';

class LocalNotes extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get encryptedContent => text()();
  TextColumn get encryptedTitle => text()();
  TextColumn get plaintextContent => text().nullable()();
  TextColumn get plaintextTitle => text().nullable()();
  IntColumn get colorIndex => integer()();
  BoolColumn get isPinned => boolean()();
  BoolColumn get isLocked => boolean()();
  TextColumn get pinHash => text().nullable()();
  TextColumn get pinSalt => text().nullable()();
  BoolColumn get localOnly => boolean()();
  TextColumn get tags => text().nullable()(); // JSON array
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 2: Create database class**

`lib/core/db/app_database.dart`:

```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [LocalNotes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'mynotes.sqlite'));
    return NativeDatabase(file);
  });
}
```

- [ ] **Step 3: Run build_runner to generate drift code**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 4: Add database provider**

`lib/core/providers/providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/db/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});
```

- [ ] **Step 5: Run analyze**

```
flutter analyze
```

- [ ] **Step 6: Commit**

```bash
git add lib/core/db/ lib/core/providers/providers.dart
git add -u
git commit -m "feat: add drift local database with notes table"
```

---

### Task 5: Create auth Riverpod providers

**Files:**
- Create: `lib/features/auth/providers/auth_providers.dart`
- Modify: `lib/core/providers/providers.dart` — keep as top-level aggregator
- Create: `test/features/auth/providers/auth_providers_test.dart`

- [ ] **Step 1: Create auth_providers.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/services/auth_service.dart';
import 'package:mynotes/core/auth/services/auth_provider.dart';
import 'package:mynotes/core/auth/services/firebase_auth_provider.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService.firebase();
});

final authStateProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserProvider = Provider<AuthUser?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull;
});
```

- [ ] **Step 2: Write provider test**

`test/features/auth/providers/auth_providers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/services/auth_service.dart';
import 'package:mynotes/core/auth/services/auth_provider.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';

class _MockAuthProvider implements AuthProvider {
  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(null);

  @override
  AuthUser? get currentUser => null;

  @override
  Future<AuthUser> createUser({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<void> logOut() async {}

  @override
  Future<AuthUser> logIn({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<AuthUser> signInWithGoogle() {
    throw UnimplementedError();
  }
}

void main() {
  test('authServiceProvider provides AuthService with Firebase provider', () {
    final container = ProviderContainer();
    final authService = container.read(authServiceProvider);
    expect(authService, isA<AuthService>());
    container.dispose();
  });

  test('authStateProvider emits null for unauthenticated', () async {
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(
          AuthService(_MockAuthProvider()),
        ),
      ],
    );

    final authState = container.read(authStateProvider);
    expect(authState.value, isNull);
    container.dispose();
  });
}
```

- [ ] **Step 3: Run test**

```bash
flutter test test/features/auth/providers/auth_providers_test.dart
```

- [ ] **Step 4: Run analyze**

```
flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/providers/ test/features/auth/providers/
git commit -m "feat: add auth Riverpod providers with tests"
```

---

### Task 6: Move views into features/auth/presentation/

**Files:**
- Move: `lib/views/login_view.dart` → `lib/features/auth/presentation/login_view.dart`
- Move: `lib/views/register_view.dart` → `lib/features/auth/presentation/register_view.dart`
- Move: `lib/views/verify_email_view.dart` → `lib/features/auth/presentation/verify_email_view.dart`
- Update imports in all moved files and in `main.dart`

- [ ] **Step 1: Create directories + move files**

```bash
mkdir -p lib/features/auth/presentation
```

Move the three view files. Update their imports:
- `login_view.dart` imports register_view, verify_email_view, auth_service, auth_exceptions, theme_toggle_button
- `register_view.dart` imports verify_email_view, auth_service, auth_exceptions, theme_toggle_button
- `verify_email_view.dart` imports main.dart (AuthenticationWrapper), auth_service, auth_exceptions, theme_toggle_button

- [ ] **Step 2: Update main.dart imports**

Update `lib/main.dart` to import from new paths:
```dart
import 'package:mynotes/features/auth/presentation/login_view.dart';
import 'package:mynotes/features/auth/presentation/verify_email_view.dart';
import 'package:mynotes/features/auth/presentation/register_view.dart';
import 'package:mynotes/features/notes/presentation/notes_home_view.dart';
```

- [ ] **Step 3: Remove old views/ directory**

```bash
Remove-Item -Recurse -Force lib/views
```

- [ ] **Step 4: Run analyze + tests**

```
flutter analyze
flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/presentation/ lib/main.dart
git add -u
git commit -m "refactor: move auth views to features/auth/presentation/"
```

---

### Task 7: Migrate views to use Riverpod providers

**Files:**
- Modify: `lib/features/auth/presentation/login_view.dart`
- Modify: `lib/features/auth/presentation/register_view.dart`
- Modify: `lib/features/auth/presentation/verify_email_view.dart`
- Modify: `lib/features/notes/presentation/notes_home_view.dart`
- Modify: `lib/features/notes/presentation/note_editor_view.dart`
- Create: `lib/features/notes/providers/notes_providers.dart`

- [ ] **Step 1: Create notes providers**

`lib/features/notes/providers/notes_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/features/notes/data/notes_service.dart';
import 'package:mynotes/features/notes/data/note.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';

final notesServiceProvider = Provider<NotesService>((ref) {
  return NotesService.instance();
});

final notesProvider = StreamProvider.family<List<Note>, String>((ref, uid) {
  final notesService = ref.watch(notesServiceProvider);
  return notesService.watchNotes(uid);
});
```

- [ ] **Step 2: Update LoginView to use Riverpod**

```dart
// At top of file, remove AuthService parameter from constructor
// Use ref.read/ref.watch instead

class LoginView extends ConsumerStatefulWidget {  // was StatefulWidget
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();  // was State
}

class _LoginViewState extends ConsumerState<LoginView> {
  // Use ref.read(authServiceProvider) instead of widget.authService
  // Use ref.read(authServiceProvider).logIn(...) etc.
}
```

Key changes in `_LoginViewState`:
- Replace `widget.authService.logIn(...)` with `ref.read(authServiceProvider).logIn(...)`
- Replace `widget.authService.signInWithGoogle()` with `ref.read(authServiceProvider).signInWithGoogle()`
- Remove `AuthService authService` parameter from widget constructor

- [ ] **Step 3: Update RegisterView to use Riverpod**

Same pattern — extend `ConsumerStatefulWidget`, use `ref.read(authServiceProvider)`.

- [ ] **Step 4: Update VerifyEmailView to use Riverpod**

Same pattern — use `ref.read(authServiceProvider)`.

- [ ] **Step 5: Update NotesHomeView to use Riverpod**

```dart
class NotesHomeView extends ConsumerStatefulWidget {  // was StatefulWidget
  final AuthUser authUser;

  const NotesHomeView({super.key, required this.authUser});

  @override
  ConsumerState<NotesHomeView> createState() => _NotesHomeViewState();
}

class _NotesHomeViewState extends ConsumerState<NotesHomeView> {
  // Use ref.watch(notesProvider(widget.authUser.uid)) instead of StreamBuilder
  // Use ref.read(notesServiceProvider) instead of _notesService field
}
```

Replace the `StreamBuilder<List<Note>>` in the build method with:
```dart
final notesAsync = ref.watch(notesProvider(widget.authUser.uid));

// Then in the sliver builder:
notesAsync.when(
  data: (notes) { /* render notes list */ },
  loading: () { /* loading spinner */ },
  error: (e, _) { /* error state */ },
);
```

- [ ] **Step 6: Update NoteEditorView to use Riverpod**

```dart
class NoteEditorView extends ConsumerStatefulWidget {
  final AuthUser authUser;
  final Note? note;

  const NoteEditorView({super.key, required this.authUser, this.note});
  // Remove NotesService parameter — use ref.read instead
}
```

- [ ] **Step 7: Update AuthenticationWrapper in main.dart**

```dart
class AuthenticationWrapper extends ConsumerWidget {  // was StatelessWidget
  // Use ref.watch(authStateProvider) instead of StreamBuilder
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    // ... same logic but with authState.when() or manual handling
  }
}
```

- [ ] **Step 8: Run analyze**

```
flutter analyze
```

- [ ] **Step 9: Run tests**

```bash
flutter test
```

- [ ] **Step 10: Commit**

```bash
git add lib/features/ lib/core/ lib/main.dart
git commit -m "feat: migrate views to Riverpod providers"
```

---

### Task 8: Create app.dart and error handling framework

**Files:**
- Create: `lib/app.dart` — extract `MyApp` and `AuthenticationWrapper` from `main.dart`
- Create: `lib/core/error/error_handler.dart`
- Modify: `lib/main.dart` — slim to initialization only
- Create: `test/core/error/error_handler_test.dart`

- [ ] **Step 1: Create app.dart**

Extract from `main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/providers/providers.dart';
import 'package:mynotes/features/auth/presentation/login_view.dart';
import 'package:mynotes/features/auth/presentation/verify_email_view.dart';
import 'package:mynotes/features/notes/presentation/notes_home_view.dart';
import 'package:mynotes/widgets/theme_toggle_button.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(  // Wrap with ProviderScope here
      child: AppThemeScope(
        isDarkMode: true,
        toggleTheme: () { /* TODO: move theme state to provider */ },
        child: MaterialApp(
          title: 'Note Log',
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: ThemeMode.dark,
          home: const AuthenticationWrapper(),
        ),
      ),
    );
  }
}

class AuthenticationWrapper extends ConsumerWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (user) {
        if (user != null) {
          if (user.isEmailVerified) {
            return NotesHomeView(authUser: user);
          }
          return const VerifyEmailView();
        }
        return const LoginView();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('Authentication error')),
      ),
    );
  }
}
```

- [ ] **Step 2: Create error handler**

`lib/core/error/error_handler.dart`:

```dart
import 'package:flutter/foundation.dart';

typedef ErrorCallback = void Function(Object error, StackTrace stack);

class AppErrorHandler {
  static final AppErrorHandler _instance = AppErrorHandler._();
  factory AppErrorHandler() => _instance;
  AppErrorHandler._();

  ErrorCallback? onError;

  void handle(Object error, StackTrace stack) {
    onError?.call(error, stack);
    if (kDebugMode) {
      debugPrint('AppError: $error\n$stack');
    }
    // Future: send to crash reporting service
  }

  void init() {
    FlutterError.onError = (details) {
      handle(details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      handle(error, stack);
      return true;
    };
  }
}
```

- [ ] **Step 3: Update main.dart**

```dart
import 'package:flutter/material.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/core/db/app_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  AppErrorHandler().init();
  runApp(const MyApp());
}
```

- [ ] **Step 4: Write error handler test**

`test/core/error/error_handler_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/error/error_handler.dart';

void main() {
  test('AppErrorHandler catches errors via callback', () {
    Object? caughtError;
    final handler = AppErrorHandler();
    handler.onError = (error, stack) {
      caughtError = error;
    };

    final testError = Exception('test');
    handler.handle(testError, StackTrace.current);

    expect(caughtError, equals(testError));
  });
}
```

- [ ] **Step 5: Run analyze + tests**

```bash
flutter analyze
flutter test
```

- [ ] **Step 6: Move theme_toggle_button.dart to features**

Move `lib/widgets/theme_toggle_button.dart` to `lib/features/settings/presentation/widgets/theme_toggle_button.dart` and update all imports.

- [ ] **Step 7: Commit**

```bash
git add lib/app.dart lib/core/error/ lib/main.dart test/core/error/
git add lib/widgets/ lib/features/settings/
git commit -m "feat: add app.dart, error handling framework, move theme toggle"
```

---

### Task 9: Clean up and verify full pass

**Files:**
- Check any remaining files in old locations
- Remove empty `lib/views/` and `lib/services/` directories
- Verify all imports reference new paths

- [ ] **Step 1: Check for remaining old-path imports**

```bash
find . -name "*.dart" -path "./lib/*" | xargs grep -l "services/auth\|services/notes\|views/"
```

If none found, proceed.

- [ ] **Step 2: Verify full build**

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: clean up old directory structure"
```
