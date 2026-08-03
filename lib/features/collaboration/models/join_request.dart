import 'package:cloud_firestore/cloud_firestore.dart';

class JoinRequest {
  final String token;
  final String recipientUid;
  final String recipientName;
  final String recipientEmail;
  final String noteId;
  final String noteTitle;
  final String status;
  final DateTime createdAt;

  const JoinRequest({
    required this.token,
    required this.recipientUid,
    required this.recipientName,
    required this.recipientEmail,
    required this.noteId,
    required this.noteTitle,
    required this.status,
    required this.createdAt,
  });

  factory JoinRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return JoinRequest(
      token: doc.reference.parent.parent!.id,
      recipientUid: doc.id,
      recipientName: data['recipientName'] as String? ?? '',
      recipientEmail: data['recipientEmail'] as String? ?? '',
      noteId: data['noteId'] as String? ?? '',
      noteTitle: data['noteTitle'] as String? ?? 'Note',
      status: data['status'] as String? ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
