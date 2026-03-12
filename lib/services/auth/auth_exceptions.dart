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
  class UserNotLoggedInAuthException implements Exception {}