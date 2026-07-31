import 'package:mynotes/core/db/app_database.dart' as db;
import 'package:mynotes/features/notes/data/notes_service.dart';

class LocalNoteRepository {
  final db.AppDatabase _database;
  // ignore: unused_field — will be used by rebuildIndex in Phase 2
  final NotesService _notesService;

  LocalNoteRepository(this._database, this._notesService);

  Future<void> rebuildIndex(String uid) async {
  }

  Future<List<String>> search(String uid, String query) async {
    return _database.searchNotes(uid, query);
  }
}
