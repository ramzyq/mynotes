import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/auth/models/auth_user.dart';
import 'package:mynotes/core/auth/services/auth_service.dart';


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
