import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/features/lock/services/biometric_unlock_service.dart';
import 'package:mynotes/features/lock/services/lock_service.dart';
import 'package:mynotes/features/notes/providers/notes_providers.dart';

final lockServiceProvider = Provider<LockService>((ref) {
  return LockService();
});

final lockAttemptStoreProvider = Provider<LockAttemptStore>((ref) {
  return LockAttemptStore();
});

final biometricUnlockServiceProvider = Provider<BiometricUnlockService>((ref) {
  return BiometricUnlockService(notesService: ref.watch(notesServiceProvider));
});
