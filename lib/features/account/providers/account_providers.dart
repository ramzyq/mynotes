import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/encryption/providers/encryption_providers.dart';
import 'package:mynotes/features/account/services/account_deletion_service.dart';
import 'package:mynotes/features/auth/providers/auth_providers.dart';
import 'package:mynotes/features/lock/providers/lock_providers.dart';
import 'package:mynotes/features/reminders/reminder_providers.dart';

final accountDeletionServiceProvider = Provider<AccountDeletionService>((ref) {
  return AccountDeletionService(
    firestore: FirebaseFirestore.instance,
    auth: ref.watch(authServiceProvider),
    deriver: ref.watch(passwordSecretDeriverProvider),
    keyManager: ref.watch(keyManagerProvider),
    onDeviceCleanup: (uid) async {
      await ref.read(biometricUnlockServiceProvider).disableAll(uid);
      await ref.read(reminderServiceProvider).cancelAll();
    },
  );
});
