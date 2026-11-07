/// What an email link's one-time code is for, from Firebase's checkActionCode.
class EmailActionInfo {
  const EmailActionInfo({this.email, this.previousEmail});

  /// The account the link was sent to. For "recover email", the address
  /// that will be restored.
  final String? email;

  /// For "recover email", the address that will be replaced.
  final String? previousEmail;
}
