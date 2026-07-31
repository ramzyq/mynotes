import 'package:mynotes/core/db/app_database.dart' as db;
import 'package:mynotes/features/notes/data/notes_service.dart';

class LocalNoteRepository {
  final db.AppDatabase _database;
  final NotesService _notesService;

  LocalNoteRepository(this._database, this._notesService);

  Future<void> rebuildIndex(String uid) async {
  }

  Future<List<String>> search(String uid, String query) async {
    return _database.searchNotes(uid, query);
  }
}
