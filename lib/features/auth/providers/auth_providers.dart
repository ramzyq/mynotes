import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/services/auth_service.dart';
import 'package:mynotes/core/encryption/providers/encryption_providers.dart';
import 'package:mynotes/features/auth/services/password_account_service.dart';


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

final passwordAccountServiceProvider = Provider<PasswordAccountService>((ref) {
  return PasswordAccountService(
    auth: ref.watch(authServiceProvider),
    deriver: ref.watch(passwordSecretDeriverProvider),
    keyBackup: ref.watch(keyBackupServiceProvider),
  );
});
