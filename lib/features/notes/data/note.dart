import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  final String id;
  final String title;
  final String content;
  final int colorIndex;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.colorIndex,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Note.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Note(
      id: doc.id,
      title: (data['title'] as String? ?? '').trim(),
      content: (data['content'] as String? ?? '').trim(),
      colorIndex: (data['colorIndex'] as int?) ?? 0,
      isPinned: (data['isPinned'] as bool?) ?? false,
      createdAt: _timestampToDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _timestampToDateTime(data['updatedAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _timestampToDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  Note copyWith({
    String? title,
    String? content,
    int? colorIndex,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      colorIndex: colorIndex ?? this.colorIndex,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'colorIndex': colorIndex,
      'isPinned': isPinned,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  String get displayTitle {
    final trimmed = title.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }

    final preview = content.trim();
    if (preview.isNotEmpty) {
      return preview.split('\n').first;
    }

    return 'Untitled note';
  }

  String get previewText {
    final combined = content.trim().isNotEmpty ? content.trim() : title.trim();
    if (combined.isEmpty) {
      return 'Start typing your note here.';
    }

    return combined.replaceAll('\n', ' ').trim();
  }
}
