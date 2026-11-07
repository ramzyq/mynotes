// Exceptions related to login
class UserNotFoundAuthException implements Exception {}
class WrongPasswordAuthException implements Exception {}
class TooManyRequestsAuthException implements Exception {}
class UserDisabledAuthException implements Exception {}
// Exceptions related to registration
class WeakPasswordAuthException implements Exception {}
class UserAlreadyExistsAuthException implements Exception {}
class InvalidCredentialAuthException implements Exception {}
// generic exceptions
class GenericAuthException implements Exception {}
/// An email link's one-time code is expired, used, or malformed.
class InvalidActionCodeAuthException implements Exception {}
/// No connection to Firebase Auth (network-request-failed).
class NetworkAuthException implements Exception {}
class UserNotLoggedInAuthException implements Exception {}
class GoogleSignInCancelledException implements Exception {}
// Password reset
/// The reset link is malformed, expired, or was already used.
class InvalidResetCodeAuthException implements Exception {}
