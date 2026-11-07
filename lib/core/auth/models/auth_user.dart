import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/foundation.dart';

@immutable
class AuthUser {
  final String uid;
  final String email;
  final String? displayName;
  final bool isEmailVerified;

  /// Whether the account signs in with email and password (and so can
  /// change it), as opposed to Google only.
  final bool hasPassword;

  const AuthUser({
    required this.uid,
    required this.email,
    this.displayName,
    required this.isEmailVerified,
    this.hasPassword = false,
  });

  factory AuthUser.fromFirebase(User user) => AuthUser(
    uid: user.uid,
    email: user.email ?? '',
    displayName: user.displayName,
    isEmailVerified: user.emailVerified,
    hasPassword: user.providerData.any((p) => p.providerId == 'password'),
  );
}
