import 'package:mynotes/features/notes/data/note.dart';

enum NoteSort { updated, created, titleAZ, tag }

Comparator<Note> noteComparator(NoteSort sort) {
  switch (sort) {
    case NoteSort.updated:
      return (a, b) => b.updatedAt.compareTo(a.updatedAt);
    case NoteSort.created:
      return (a, b) => b.createdAt.compareTo(a.createdAt);
    case NoteSort.titleAZ:
      return (a, b) => a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase());
    case NoteSort.tag:
      return (a, b) {
        final at = (a.tags?.firstOrNull ?? '').toLowerCase();
        final bt = (b.tags?.firstOrNull ?? '').toLowerCase();
        final byTag = at.compareTo(bt);
        if (byTag != 0) return byTag;
        return a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase());
      };
  }
}
